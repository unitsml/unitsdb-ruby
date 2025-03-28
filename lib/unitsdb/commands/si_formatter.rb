# frozen_string_literal: true

require "terminal-table"
require_relative "si_ttl_parser"

module Unitsdb
  module Commands
    # Formatter for SI check results
    module SiFormatter
      module_function

      # Display TTL → DB results
      def display_si_results(entity_type, matches, missing_matches, unmatched_ttl)
        puts "\n=== #{entity_type.capitalize} with matching SI references ==="
        if matches.empty?
          puts "None"
        else
          rows = []
          matches.each do |match|
            si_suffix = SiTtlParser.extract_identifying_suffix(match[:si_uri])
            rows << [
              "UnitsDB: #{match[:entity_id]}",
              "(#{match[:entity_name] || "unnamed"})"
            ]
            rows << [
              "SI TTL:  #{si_suffix}",
              "(#{match[:si_label] || match[:si_name] || "unnamed"})"
            ]
            rows << :separator unless match == matches.last
          end

          table = Terminal::Table.new(
            title: "Valid SI Reference Mappings",
            rows: rows
          )
          puts table
        end

        puts "\n=== #{entity_type.capitalize} without SI references ==="
        if missing_matches.empty?
          puts "None"
        else
          # Split matches into exact and potential
          exact_matches = []
          potential_matches = []

          missing_matches.each do |match|
            # Get match details
            match_details = match[:match_details]
            match_desc = match_details&.dig(:match_desc) || ""

            # Symbol matches and partial matches should always be potential matches
            if %w[symbol_match partial_match].include?(match_desc)
              potential_matches << match
            elsif match_details&.dig(:exact) == false
              potential_matches << match
            else
              exact_matches << match
            end
          end

          # Display exact matches
          puts "\n=== Exact Matches (#{exact_matches.size}) ==="
          if exact_matches.empty?
            puts "None"
          else
            rows = []
            exact_matches.each do |match|
              # First row: UnitsDB entity
              rows << [
                "UnitsDB: #{match[:entity_id]}",
                "(#{match[:entity_name] || "unnamed"})"
              ]

              # Handle multiple SI matches in a single cell if present
              if match[:multiple_si]
                # Ensure no duplicate URIs
                si_text_parts = []
                si_label_parts = []
                seen_uris = {}

                match[:multiple_si].each do |si_data|
                  uri = si_data[:uri]
                  next if seen_uris[uri] # Skip if we've already seen this URI

                  seen_uris[uri] = true

                  suffix = SiTtlParser.extract_identifying_suffix(uri)
                  si_text_parts << suffix
                  si_label_parts << (si_data[:label] || si_data[:name])
                end

                rows << [
                  "SI TTL:  #{si_text_parts.join(", ")}",
                  "(#{si_label_parts.join(", ")})"
                ]
              else
                # Second row: SI TTL suffix and label/name
                si_suffix = SiTtlParser.extract_identifying_suffix(match[:si_uri])
                rows << [
                  "SI TTL:  #{si_suffix}",
                  "(#{match[:si_label] || match[:si_name] || "unnamed"})"
                ]
              end

              # Status line with match type
              match_details = match[:match_details]
              match_desc = match_details&.dig(:match_desc) || ""
              match_info = format_match_info(match_desc)
              status_text = match_info.empty? ? "Missing reference" : "Missing reference (#{match_info})"

              rows << [
                "Status: #{status_text}",
                "✗"
              ]
              rows << :separator unless match == exact_matches.last
            end

            table = Terminal::Table.new(
              title: "Exact Match Missing SI References",
              rows: rows
            )
            puts table
          end

          # Display potential matches
          puts "\n=== Potential Matches (#{potential_matches.size}) ==="
          if potential_matches.empty?
            puts "None"
          else
            rows = []
            potential_matches.each do |match|
              # First row: UnitsDB entity
              rows << [
                "UnitsDB: #{match[:entity_id]}",
                "(#{match[:entity_name] || "unnamed"})"
              ]

              # Handle multiple SI matches in a single cell if present
              if match[:multiple_si]
                # Ensure no duplicate URIs
                si_text_parts = []
                seen_uris = {}

                match[:multiple_si].each do |si_data|
                  uri = si_data[:uri]
                  next if seen_uris[uri] # Skip if we've already seen this URI

                  seen_uris[uri] = true

                  suffix = SiTtlParser.extract_identifying_suffix(uri)
                  si_text_parts << "#{suffix} (#{si_data[:label] || si_data[:name]})"
                end

                rows << [
                  "SI TTL:  #{si_text_parts.join(", ")}",
                  ""
                ]
              else
                # Single TTL entity
                si_suffix = SiTtlParser.extract_identifying_suffix(match[:si_uri])
                rows << [
                  "SI TTL:  #{si_suffix}",
                  "(#{match[:si_label] || match[:si_name] || "unnamed"})"
                ]
              end

              # Status line
              match_details = match[:match_details]
              match_desc = match_details&.dig(:match_desc) || ""
              match_info = format_match_info(match_desc)
              status_text = match_info.empty? ? "Missing reference" : "Missing reference"

              rows << [
                "Status: #{status_text}",
                "✗"
              ]
              rows << :separator unless match == potential_matches.last
            end

            table = Terminal::Table.new(
              title: "Potential Match Missing SI References",
              rows: rows
            )
            puts table
          end
        end

        puts "\n=== SI #{entity_type.capitalize} not mapped to our database ==="
        if unmatched_ttl.empty?
          puts "None (All TTL entities are referenced - Good job!)"
        else
          # Group unmatched ttl entities by their URI to avoid duplicates
          grouped_unmatched = {}

          unmatched_ttl.each do |entity|
            uri = entity[:uri]
            grouped_unmatched[uri] = entity unless grouped_unmatched.key?(uri)
          end

          rows = []
          unique_entities = grouped_unmatched.values

          unique_entities.each do |entity|
            # Create the SI TTL row
            si_suffix = SiTtlParser.extract_identifying_suffix(entity[:uri])
            ttl_row = ["SI TTL:  #{si_suffix}", "(#{entity[:label] || entity[:name] || "unnamed"})"]

            rows << ttl_row
            rows << [
              "Status: No matching UnitsDB entity",
              "?"
            ]
            rows << :separator unless entity == unique_entities.last
          end

          table = Terminal::Table.new(
            title: "Unmapped SI Entities",
            rows: rows
          )
          puts table
        end
      end

      # Display DB → TTL results
      def display_db_results(entity_type, matches, missing_refs, unmatched_db)
        puts "\n=== Summary of database entities referencing SI ==="
        puts "#{entity_type.capitalize} with SI references: #{matches.size}"
        puts "#{entity_type.capitalize} missing SI references: #{missing_refs.size}"
        puts "Database #{entity_type} not matching any SI entity: #{unmatched_db.size}"

        # Show entities with valid references
        unless matches.empty?
          puts "\n=== #{entity_type.capitalize} with SI references ==="
          rows = []
          matches.each do |match|
            db_entity = match[:db_entity]
            entity_id = match[:entity_id] || db_entity.short
            entity_name = db_entity.respond_to?(:names) ? db_entity.names&.first : "unnamed"
            si_suffix = SiTtlParser.extract_identifying_suffix(match[:ttl_uri])

            ttl_label = match[:ttl_entity] ? (match[:ttl_entity][:label] || match[:ttl_entity][:name]) : "Unknown"

            rows << [
              "UnitsDB: #{entity_id}",
              "(#{entity_name})"
            ]
            rows << [
              "SI TTL:  #{si_suffix}",
              "(#{ttl_label})"
            ]
            rows << :separator unless match == matches.last
          end

          table = Terminal::Table.new(
            title: "Valid SI References",
            rows: rows
          )
          puts table
        end

        puts "\n=== #{entity_type.capitalize} that should reference SI ==="
        if missing_refs.empty?
          puts "None"
        else
          # Split missing_refs into exact and potential matches
          exact_matches = []
          potential_matches = []

          missing_refs.each do |match|
            # Determine match type
            ttl_entities = match[:ttl_entities]
            uri = ttl_entities.first[:uri]
            match_type = "Exact match" # Default
            match_type = match[:match_types][uri] if match[:match_types] && match[:match_types][uri]

            # Get match description if available
            entity_id = match[:db_entity].short
            match_pair_key = "#{entity_id}:#{ttl_entities.first[:uri]}"
            match_details = Unitsdb::Commands::SiMatcher.instance_variable_get(:@match_details)&.dig(match_pair_key)
            match_desc = match_details[:match_desc] if match_details && match_details[:match_desc]

            # Symbol matches and partial matches should always be potential matches
            if %w[symbol_match partial_match].include?(match_desc)
              potential_matches << match
            elsif match_type == "Exact match"
              exact_matches << match
            else
              potential_matches << match
            end
          end

          # Display exact matches
          puts "\n=== Exact Matches (#{exact_matches.size}) ==="
          if exact_matches.empty?
            puts "None"
          else
            rows = []
            exact_matches.each do |match|
              db_entity = match[:db_entity]
              entity_id = match[:entity_id] || db_entity.short
              entity_name = db_entity.respond_to?(:names) ? db_entity.names&.first : "unnamed"

              # Handle multiple TTL entities in a single row
              ttl_entities = match[:ttl_entities]
              if ttl_entities.size == 1
                # Single TTL entity
                ttl_entity = ttl_entities.first
                si_suffix = SiTtlParser.extract_identifying_suffix(ttl_entity[:uri])

                rows << [
                  "UnitsDB: #{entity_id}",
                  "(#{entity_name})"
                ]
                rows << [
                  "SI TTL:  #{si_suffix}",
                  "(#{ttl_entity[:label] || ttl_entity[:name] || "unnamed"})"
                ]
              else
                # Multiple TTL entities, combine them - ensure no duplicates
                si_text_parts = []
                seen_uris = {}

                ttl_entities.each do |ttl_entity|
                  uri = ttl_entity[:uri]
                  next if seen_uris[uri] # Skip if we've already seen this URI

                  seen_uris[uri] = true

                  suffix = SiTtlParser.extract_identifying_suffix(uri)
                  si_text_parts << "#{suffix} (#{ttl_entity[:label] || ttl_entity[:name] || "unnamed"})"
                end

                si_text = si_text_parts.join(", ")

                rows << [
                  "UnitsDB: #{entity_id}",
                  "(#{entity_name})"
                ]
                rows << [
                  "SI TTL:  #{si_text}",
                  ""
                ]
              end

              # Get match details for this match
              match_pair_key = "#{db_entity.short}:#{ttl_entities.first[:uri]}"
              match_details = Unitsdb::Commands::SiMatcher.instance_variable_get(:@match_details)&.dig(match_pair_key)

              # Format match info
              match_info = ""
              match_info = format_match_info(match_details[:match_desc]) if match_details

              status_text = match_info.empty? ? "Missing reference" : "Missing reference (#{match_info})"
              rows << [
                "Status: #{status_text}",
                "✗"
              ]
              rows << :separator unless match == exact_matches.last
            end

            table = Terminal::Table.new(
              title: "Exact Match Missing SI References",
              rows: rows
            )
            puts table
          end

          # Display potential matches
          puts "\n=== Potential Matches (#{potential_matches.size}) ==="
          if potential_matches.empty?
            puts "None"
          else
            rows = []
            potential_matches.each do |match|
              db_entity = match[:db_entity]
              entity_id = match[:entity_id] || db_entity.short
              entity_name = db_entity.respond_to?(:names) ? db_entity.names&.first : "unnamed"

              # Handle multiple TTL entities in a single row
              ttl_entities = match[:ttl_entities]
              if ttl_entities.size == 1
                # Single TTL entity
                ttl_entity = ttl_entities.first
                si_suffix = SiTtlParser.extract_identifying_suffix(ttl_entity[:uri])

                rows << [
                  "UnitsDB: #{entity_id}",
                  "(#{entity_name})"
                ]
                rows << [
                  "SI TTL:  #{si_suffix}",
                  "(#{ttl_entity[:label] || ttl_entity[:name] || "unnamed"})"
                ]
              else
                # Multiple TTL entities, combine them - ensure no duplicates
                si_text_parts = []
                seen_uris = {}

                ttl_entities.each do |ttl_entity|
                  uri = ttl_entity[:uri]
                  next if seen_uris[uri] # Skip if we've already seen this URI

                  seen_uris[uri] = true

                  suffix = SiTtlParser.extract_identifying_suffix(uri)
                  si_text_parts << "#{suffix} (#{ttl_entity[:label] || ttl_entity[:name] || "unnamed"})"
                end

                si_text = si_text_parts.join(", ")

                rows << [
                  "UnitsDB: #{entity_id}",
                  "(#{entity_name})"
                ]
                rows << [
                  "SI TTL:  #{si_text}",
                  ""
                ]
              end

              # Get match details
              match_pair_key = "#{db_entity.short}:#{ttl_entities.first[:uri]}"
              match_details = Unitsdb::Commands::SiMatcher.instance_variable_get(:@match_details)&.dig(match_pair_key)

              # Format match info
              match_info = ""
              match_info = format_match_info(match_details[:match_desc]) if match_details

              status_text = match_info.empty? ? "Missing reference" : "Missing reference (#{match_info})"
              rows << [
                "Status: #{status_text}",
                "✗"
              ]
              rows << :separator unless match == potential_matches.last
            end

            table = Terminal::Table.new(
              title: "Potential Match Missing SI References",
              rows: rows
            )
            puts table
          end
        end
      end

      # Print direction header
      def print_direction_header(direction)
        case direction
        when "SI → UnitsDB"
          puts "\n=== Checking SI → UnitsDB (TTL entities referenced by database) ==="
        when "UnitsDB → SI"
          puts "\n=== Checking UnitsDB → SI (database entities referencing TTL) ==="
        end

        puts "\n=== Instructions for #{direction} direction ==="
        case direction
        when "SI → UnitsDB"
          puts "If you are the UnitsDB Register Manager, please ensure that all SI entities have proper references in the UnitsDB database."
          puts "For each missing reference, add a reference with the appropriate URI and 'authority: \"si-digital-framework\"'."
        when "UnitsDB → SI"
          puts "If you are the UnitsDB Register Manager, please add SI references to UnitsDB entities that should have them."
          puts "For each entity that should reference SI, add a reference with 'authority: \"si-digital-framework\"' and the SI TTL URI."
        end
      end

      def set_match_details(details)
        @match_details = details
      end

      # Format match info for display
      def format_match_info(match_desc)
        {
          "short_to_name" => "short → name",
          "short_to_label" => "short → label",
          "name_to_name" => "name → name",
          "name_to_label" => "name → label",
          "name_to_alt_label" => "name → alt_label",
          "symbol_match" => "symbol → symbol",
          "partial_match" => "partial match"
        }[match_desc] || ""
      end
    end
  end
end
