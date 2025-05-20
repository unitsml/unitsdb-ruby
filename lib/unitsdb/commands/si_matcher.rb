# frozen_string_literal: true

require_relative "si_ttl_parser"

module Unitsdb
  module Commands
    # Matcher for SI entities and UnitsDB entities
    module SiMatcher
      SI_AUTHORITY = "si-digital-framework"
      @match_details = {}

      module_function

      # Match TTL entities to database entities (from_si direction)
      def match_ttl_to_db(entity_type, ttl_entities, db_entities)
        matches = []
        missing_matches = []
        matched_ttl_uris = []
        processed_pairs = {} # Track processed entity-ttl pairs to avoid duplicates
        entity_matches = {} # Track matches by entity ID

        # First pass: find direct references
        db_entities.each do |entity|
          next unless entity.respond_to?(:references) && entity.references

          entity.references.each do |ref|
            next unless ref.authority == SI_AUTHORITY

            matched_ttl_uris << ref.uri
            ttl_entity = ttl_entities.find { |e| e[:uri] == ref.uri }
            next unless ttl_entity

            matches << {
              entity_id: entity.short,
              entity_name: format_entity_name(entity),
              si_uri: ttl_entity[:uri],
              si_name: ttl_entity[:name],
              si_label: ttl_entity[:label],
              si_alt_label: ttl_entity[:alt_label],
              si_symbol: ttl_entity[:symbol],
              entity: entity
            }
          end
        end

        # Second pass: find matching entities
        ttl_entities.each do |ttl_entity|
          next if matched_ttl_uris.include?(ttl_entity[:uri])

          matching_entities = find_matching_entities(entity_type, ttl_entity, db_entities)
          next if matching_entities.empty?

          matched_ttl_uris << ttl_entity[:uri]

          matching_entities.each do |entity|
            entity_id = entity.short
            entity_name = format_entity_name(entity)

            # Create a unique key for this entity-ttl pair to avoid duplicates
            pair_key = "#{entity_id}:#{ttl_entity[:uri]}"
            next if processed_pairs[pair_key]

            processed_pairs[pair_key] = true

            # Get detailed match information
            match_result = match_entity_names?(entity_type, entity, ttl_entity)
            next unless match_result[:match]

            # Save match details for later use
            @match_details[pair_key] = match_result

            # Check if already has reference
            has_reference = entity.references&.any? do |ref|
              ref.uri == ttl_entity[:uri] && ref.authority == SI_AUTHORITY
            end

            match_data = {
              entity_id: entity_id,
              entity_name: entity_name,
              si_uri: ttl_entity[:uri],
              si_name: ttl_entity[:name],
              si_label: ttl_entity[:label],
              si_alt_label: ttl_entity[:alt_label],
              si_symbol: ttl_entity[:symbol],
              entity: entity,
              match_type: match_result[:match_type],
              match_details: match_result,
              match_types: { ttl_entity[:uri] => match_result[:match_type] }
            }

            if has_reference
              matches << match_data
            else
              # Group by entity_id for multiple SI matches
              entity_matches[entity_id] ||= []
              entity_matches[entity_id] << {
                uri: ttl_entity[:uri],
                name: ttl_entity[:name],
                label: ttl_entity[:label]
              }

              # Add first occurrence of this entity to missing_matches
              missing_matches << match_data unless missing_matches.any? { |m| m[:entity_id] == entity_id }
            end
          end
        end

        # Update missing_matches to include multiple SI entities
        missing_matches.each do |match|
          entity_id = match[:entity_id]
          si_matches = entity_matches[entity_id]

          # If entity matches multiple SI entities, record them
          match[:multiple_si] = si_matches if si_matches && si_matches.size > 1
        end

        # Find unmatched TTL entities
        unmatched_ttl = ttl_entities.reject do |entity|
          matched_ttl_uris.include?(entity[:uri]) ||
            entity[:uri].end_with?("/units/") ||
            entity[:uri].end_with?("/quantities/") ||
            entity[:uri].end_with?("/prefixes/")
        end

        [matches, missing_matches, unmatched_ttl]
      end

      # Match database entities to TTL entities (to_si direction)
      def match_db_to_ttl(entity_type, ttl_entities, db_entities)
        matches = []
        missing_refs = []
        matched_db_ids = []
        processed_db_ids = {} # Track processed entities

        # Map from NIST IDs to display names for original output compatibility
        nist_id_to_display = {}

        # Build mappings for each entity type
        db_entities.each do |entity|
          next unless entity.respond_to?(:identifiers) && entity.identifiers&.first&.id&.start_with?("NIST")

          nist_id = entity.identifiers.first.id

          # For quantities and prefixes, we want to show the "short" field
          nist_id_to_display[nist_id] = entity.short if %w[quantities
                                                           prefixes].include?(entity_type) && entity.respond_to?(:short)
        end

        db_entities.each do |db_entity|
          entity_id = find_entity_id(db_entity)

          # For display purposes - use original display names
          display_id = entity_id

          # Apply the NIST ID mapping if available
          display_id = nist_id_to_display[entity_id] if entity_id.start_with?("NIST") && nist_id_to_display[entity_id]

          # Skip if we've already processed this entity
          next if processed_db_ids[entity_id]

          processed_db_ids[entity_id] = true
          has_reference = false

          # Check for existing SI references
          if db_entity.respond_to?(:references) && db_entity.references
            db_entity.references.each do |ref|
              next unless ref.authority == SI_AUTHORITY

              has_reference = true
              # Find the matching TTL entity for display
              ttl_entity = ttl_entities.find { |e| e[:uri] == ref.uri }

              matches << {
                entity_id: display_id,
                db_entity: db_entity,
                ttl_uri: ref.uri,
                ttl_entity: ttl_entity
              }
            end
          end

          # If already has reference, continue to next entity
          if has_reference
            matched_db_ids << entity_id
            next
          end

          # Find matching TTL entities
          matching_ttl = []
          match_types = {}

          ttl_entities.each do |ttl_entity|
            match_result = match_entity_names?(entity_type, db_entity, ttl_entity)
            next unless match_result[:match]

            matching_ttl << ttl_entity
            match_types[ttl_entity[:uri]] = match_result[:match_type]

            # Save detailed match info
            @match_details["#{entity_id}:#{ttl_entity[:uri]}"] = match_result
          end

          # If found matches, add to missing_refs
          next if matching_ttl.empty?

          matched_db_ids << entity_id
          missing_refs << {
            entity_id: display_id,
            db_entity: db_entity,
            ttl_entities: matching_ttl,
            match_types: match_types
          }
        end

        # Find unmatched db entities
        unmatched_db = db_entities.reject { |entity| matched_db_ids.include?(find_entity_id(entity)) }

        [matches, missing_refs, unmatched_db]
      end

      # Find entity ID
      def find_entity_id(entity)
        return entity.id if entity.respond_to?(:id) && entity.id
        return entity.identifiers.first.id if entity.respond_to?(:identifiers) && !entity.identifiers.empty? &&
                                              entity.identifiers.first.respond_to?(:id)

        entity.short
      end

      # Format entity name correctly
      def format_entity_name(entity)
        return nil unless entity.respond_to?(:names) && entity.names&.first

        entity.names.first

        # # Special handling for sidereal names - use comma format
        # if name.include?("sidereal")
        #   if name.start_with?("sidereal ")
        #     # For names that already start with "sidereal " - strip it
        #     base_name = name.gsub("sidereal ", "")
        #     return "#{base_name}, sidereal"
        #   elsif name.end_with?(" sidereal")
        #     # For names that already have comma format but missing comma
        #     parts = name.split
        #     return "#{parts.first}, #{parts.last}"
        #   end
        # end

        # # Handle other special cases
        # return name if name == "year (365 days)"

        # # Default to the original name
      end

      # Find matching entities for a TTL entity
      def find_matching_entities(entity_type, ttl_entity, db_entities)
        case entity_type
        when "units"
          find_matching_units(ttl_entity, db_entities)
        when "quantities"
          find_matching_quantities(ttl_entity, db_entities)
        when "prefixes"
          find_matching_prefixes(ttl_entity, db_entities)
        else
          []
        end
      end

      # Find exact matches for units
      def find_matching_units(ttl_unit, units)
        matching_units = []

        units.each do |unit|
          # Match by short
          if unit.short&.downcase == ttl_unit[:name]&.downcase ||
             unit.short&.downcase == ttl_unit[:label]&.downcase
            matching_units << unit
            next
          end

          # Match by name
          if unit.respond_to?(:names) && unit.names&.any? do |name|
            name.downcase == ttl_unit[:name]&.downcase ||
            name.downcase == ttl_unit[:label]&.downcase
          end
            matching_units << unit
            next
          end

          # Match by symbol
          next unless ttl_unit[:symbol] && unit.respond_to?(:symbols) && unit.symbols&.any? do |sym|
            sym.respond_to?(:ascii) && sym.ascii && sym.ascii.downcase == ttl_unit[:symbol].downcase
          end

          matching_units << unit
        end

        matching_units.uniq
      end

      # Find exact matches for quantities
      def find_matching_quantities(ttl_quantity, quantities)
        matching_quantities = []

        quantities.each do |quantity|
          # Match by short
          if quantity.short&.downcase == ttl_quantity[:name]&.downcase ||
             quantity.short&.downcase == ttl_quantity[:label]&.downcase ||
             quantity.short&.downcase == ttl_quantity[:alt_label]&.downcase
            matching_quantities << quantity
            next
          end

          # Match by name
          next unless quantity.respond_to?(:names) && quantity.names&.any? do |name|
            name.downcase == ttl_quantity[:name]&.downcase ||
            name.downcase == ttl_quantity[:label]&.downcase ||
            name.downcase == ttl_quantity[:alt_label]&.downcase
          end

          matching_quantities << quantity
        end

        matching_quantities.uniq
      end

      # Find exact matches for prefixes
      def find_matching_prefixes(ttl_prefix, prefixes)
        matching_prefixes = []

        prefixes.each do |prefix|
          # Match by short
          if prefix.short&.downcase == ttl_prefix[:name]&.downcase ||
             prefix.short&.downcase == ttl_prefix[:label]&.downcase
            matching_prefixes << prefix
            next
          end

          # Match by name
          if prefix.respond_to?(:names) && prefix.names&.any? do |name|
            name.downcase == ttl_prefix[:name]&.downcase ||
            name.downcase == ttl_prefix[:label]&.downcase
          end
            matching_prefixes << prefix
            next
          end

          # Match by symbol
          next unless ttl_prefix[:symbol] && prefix.respond_to?(:symbol) && prefix.symbol &&
                      prefix.symbol.respond_to?(:ascii) && prefix.symbol.ascii &&
                      prefix.symbol.ascii.downcase == ttl_prefix[:symbol].downcase

          matching_prefixes << prefix
        end

        matching_prefixes.uniq
      end

      # Match entity names with detailed type information
      def match_entity_names?(entity_type, db_entity, ttl_entity)
        match_details = { match: false }

        # Match by short name - EXACT match
        if db_entity.short && db_entity.short.downcase == ttl_entity[:name].downcase
          match_details = {
            match: true,
            exact: true,
            match_type: "Exact match",
            match_desc: "short_to_name",
            details: "UnitsDB short '#{db_entity.short}' matches SI name '#{ttl_entity[:name]}'"
          }
        # Match by short to label
        elsif db_entity.short && ttl_entity[:label] && db_entity.short.downcase == ttl_entity[:label].downcase
          match_details = {
            match: true,
            exact: true,
            match_type: "Exact match",
            match_desc: "short_to_label",
            details: "UnitsDB short '#{db_entity.short}' matches SI label '#{ttl_entity[:label]}'"
          }
        # Match by names - EXACT match
        elsif db_entity.respond_to?(:names) && db_entity.names
          # Match by TTL name
          db_name_match = db_entity.names.find { |name| name.downcase == ttl_entity[:name].downcase }
          if db_name_match
            match_details = {
              match: true,
              exact: true,
              match_type: "Exact match",
              match_desc: "name_to_name",
              details: "UnitsDB name '#{db_name_match}' matches SI name '#{ttl_entity[:name]}'"
            }
          # Match by TTL label
          elsif ttl_entity[:label]
            db_name_match = db_entity.names.find { |name| name.downcase == ttl_entity[:label].downcase }
            if db_name_match
              match_details = {
                match: true,
                exact: true,
                match_type: "Exact match",
                match_desc: "name_to_label",
                details: "UnitsDB name '#{db_name_match}' matches SI label '#{ttl_entity[:label]}'"
              }
            end
          end

          # Match by TTL alt_label
          if !match_details[:match] && ttl_entity[:alt_label]
            db_name_match = db_entity.names.find { |name| name.downcase == ttl_entity[:alt_label].downcase }
            if db_name_match
              match_details = {
                match: true,
                exact: true,
                match_type: "Exact match",
                match_desc: "name_to_alt_label",
                details: "UnitsDB name '#{db_name_match}' matches SI alt_label '#{ttl_entity[:alt_label]}'"
              }
            end
          end
        end

        # Special validation for "sidereal_" units
        if match_details[:match] && match_details[:exact] && db_entity.short&.include?("sidereal_") &&
           !(ttl_entity[:name]&.include?("sidereal") || ttl_entity[:label]&.include?("sidereal"))
          match_details = {
            match: true,
            exact: false,
            match_type: "Potential match",
            match_desc: "partial_match",
            details: "UnitsDB '#{db_entity.short}' partially matches SI '#{ttl_entity[:name]}'"
          }
        end

        # Match by symbol if available (units and prefixes) - POTENTIAL match
        if !match_details[:match] && %w[units prefixes].include?(entity_type) && ttl_entity[:symbol]
          if entity_type == "units" && db_entity.respond_to?(:symbols) && db_entity.symbols
            matching_symbol = db_entity.symbols.find do |sym|
              sym.respond_to?(:ascii) && sym.ascii && sym.ascii.downcase == ttl_entity[:symbol].downcase
            end

            if matching_symbol
              match_details = {
                match: true,
                exact: false,
                match_type: "Potential match",
                match_desc: "symbol_match",
                details: "UnitsDB symbol '#{matching_symbol.ascii}' matches SI symbol '#{ttl_entity[:symbol]}'"
              }
            end
          elsif entity_type == "prefixes" && db_entity.respond_to?(:symbol) && db_entity.symbol
            if db_entity.symbol.respond_to?(:ascii) &&
               db_entity.symbol.ascii &&
               db_entity.symbol.ascii.downcase == ttl_entity[:symbol].downcase

              match_details = {
                match: true,
                exact: false,
                match_type: "Potential match",
                match_desc: "symbol_match",
                details: "UnitsDB symbol '#{db_entity.symbol.ascii}' matches SI symbol '#{ttl_entity[:symbol]}'"
              }
            end
          end
        end

        match_details
      end
    end
  end
end
