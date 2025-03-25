# frozen_string_literal: true

require "rdf"
require "rdf/turtle"
require "yaml"
require "fileutils"
require "terminal-table"
require_relative "base"
require_relative "../utils"
require_relative "../database"
require_relative "../external_reference"
require_relative "../errors"

module Unitsdb
  module Commands
    class CheckSi < Base
      # Entity types supported by this command
      ENTITY_TYPES = %w[units quantities prefixes].freeze

      def run
        # Get @options
        entity_type = @options[:entity_type]&.downcase
        direction = @options[:direction]&.downcase || "both"
        output_dir = @options[:output_updated_database]
        include_potential = @options[:include_potential_matches] || false

        # Use the path as-is without expansion
        database_path = @options[:database]
        puts "Using database directory: #{database_path}"

        # Validate direction
        unless %w[to_si from_si both].include?(direction)
          puts "Invalid direction: #{direction}. Must be one of: to_si, from_si, both"
          exit(1)
        end

        # Make sure the database is loaded with full path to the directory
        @db = Unitsdb::Database.from_db(database_path)

        # Validate TTL directory
        ttl_dir = @options[:ttl_dir]
        unless Dir.exist?(ttl_dir)
          puts "TTL directory not found: #{ttl_dir}"
          exit(1)
        end

        puts "Using TTL directory: #{ttl_dir}"
        puts "Include potential matches: #{include_potential ? "Yes" : "No"}"

        # Parse all TTL files once
        graph = parse_ttl_files(ttl_dir)

        # Process entity types
        if entity_type && ENTITY_TYPES.include?(entity_type)
          # Process only the specified entity type
          process_entity_type(entity_type, @db, graph, direction, output_dir, include_potential)
        else
          # Process all entity types
          ENTITY_TYPES.each do |type|
            process_entity_type(type, @db, graph, direction, output_dir, include_potential)
          end
        end
      end

      private

      # Extract identifying suffix from SI TTL URI
      def extract_identifying_suffix(uri)
        return "" unless uri

        # Remove the prefix http://si-digital-framework.org/SI/
        uri.gsub("http://si-digital-framework.org/SI/", "")
      end

      def process_entity_type(entity_type, db, graph, direction, output_dir, include_potential = false)
        puts "\n========== Processing #{entity_type.upcase} References ==========\n"

        # Get entities from DB and TTL
        db_entities = db.send(entity_type)
        ttl_entities = extract_entities_from_ttl(entity_type, graph)

        puts "Found #{ttl_entities.size} #{entity_type} in SI digital framework"
        puts "Found #{db_entities.size} #{entity_type} in database"

        # Check direction: from_si (TTL→UnitsDB)
        check_from_si(entity_type, ttl_entities, db_entities, output_dir) if %w[from_si both].include?(direction)

        # Check direction: to_si (UnitsDB→TTL)
        return unless %w[to_si both].include?(direction)

        check_to_si(entity_type, ttl_entities, db_entities, output_dir, include_potential)
      end

      def check_from_si(entity_type, ttl_entities, db_entities, output_dir, include_potential = false)
        puts "\n=== Checking SI → UnitsDB (TTL entities referenced by database) ==="

        # Find TTL entities referenced by database entities
        matches, missing_matches, unmatched_ttl = match_ttl_to_db(entity_type, ttl_entities, db_entities)

        # Print instructions for this direction
        puts "\n=== Instructions for SI → UnitsDB direction ==="
        puts "If you are the UnitsDB Register Manager, please ensure that all SI entities have proper references in the UnitsDB database."
        puts "For each missing reference, add a reference with the appropriate URI and 'authority: \"si-digital-framework\"'."

        # Print results in table format
        puts "\n=== #{entity_type.capitalize} with matching SI references ==="
        if matches.empty?
          puts "None"
        else
          rows = []
          matches.each do |match|
            si_suffix = extract_identifying_suffix(match[:si_uri])
            rows << [
              "UnitsDB: #{match[:entity_id]}",
              "(#{match[:entity_name]})"
            ]
            rows << [
              "SI TTL:  #{si_suffix}",
              "(#{match[:si_label] || match[:si_name]})"
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
            # Get match type - default to "Exact match"
            match_type = "Exact match" # Default
            if match[:match_types] && !match[:match_types].empty?
              uri = ttl_entities.first[:uri]
              match_type = match[:match_types][uri] if match[:match_types][uri]
            end

            # Get match description (short_to_name, symbol_match, etc.)
            match_desc = ""
            match_desc = match[:match_details][:match_desc] if match[:match_details] && match[:match_details][:match_desc]

            # Symbol matches and partial matches should always be potential matches, regardless of match_type
            if %w[symbol_match partial_match].include?(match_desc)
              potential_matches << match
            # Otherwise, categorize based on match_type
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
              si_suffix = extract_identifying_suffix(match[:si_uri])

              # First row: UnitsDB short and name
              rows << [
                "UnitsDB: #{match[:entity_id]}",
                "(#{match[:entity_name]})"
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

                  suffix = extract_identifying_suffix(uri)
                  si_text_parts << suffix
                  si_label_parts << (si_data[:label] || si_data[:name])
                end

                rows << [
                  "SI TTL:  #{si_text_parts.join(", ")}",
                  "(#{si_label_parts.join(", ")})"
                ]
              else
                # Second row: SI TTL suffix and label/name
                rows << [
                  "SI TTL:  #{si_suffix}",
                  "(#{match[:si_label] || match[:si_name]})"
                ]
              end

              # Get match details if not already present
              unless match.key?(:match_details)
                # Find the TTL entity for this match
                current_ttl_entity = ttl_entities.find { |e| e[:uri] == match[:si_uri] }
                if current_ttl_entity
                  # Get match details from match result
                  match_result = match_entity_names?(entity_type, match[:entity], current_ttl_entity)
                  match[:match_details] = match_result if match_result[:match]
                end
              end

              # Get match type directly from match
              match_desc = match[:match_details]&.dig(:match_desc) || ""
              match_info = case match_desc
                           when "short_to_name"
                             "short → name"
                           when "short_to_label"
                             "short → label"
                           when "name_to_name"
                             "name → name"
                           when "name_to_label"
                             "name → label"
                           when "name_to_alt_label"
                             "name → alt_label"
                           when "symbol_match"
                             "symbol → symbol"
                           when "partial_match"
                             "partial match"
                           else
                             ""
                           end

              rows << [
                "Status: Missing reference (#{match_info})",
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
              si_suffix = extract_identifying_suffix(match[:si_uri])
              rows << [
                "UnitsDB: #{match[:entity_id]}",
                "(#{match[:entity_name]})"
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

                  suffix = extract_identifying_suffix(uri)
                  si_text_parts << "#{suffix} (#{si_data[:label] || si_data[:name]})"
                end

                rows << [
                  "SI TTL:  #{si_text_parts.join(", ")}",
                  ""
                ]
              else
                rows << [
                  "SI TTL:  #{si_suffix}",
                  "(#{match[:si_label] || match[:si_name]})"
                ]
              end

              # Get match details for display
              entity_id = match[:entity_id]
              match_pair_key = "#{entity_id}:#{ttl_entities.first[:uri]}"
              match_details = @match_details&.dig(match_pair_key) if @match_details

              # Format match info
              match_info = ""
              if match_details
                match_info = case match_details[:match_desc]
                             when "short_to_name"
                               "short → name"
                             when "short_to_label"
                               "short → label"
                             when "name_to_name"
                               "name → name"
                             when "name_to_label"
                               "name → label"
                             when "name_to_alt_label"
                               "name → alt_label"
                             when "symbol_match"
                               "symbol → symbol"
                             when "partial_match"
                               "partial match"
                             else
                               ""
                             end
              end

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
            si_suffix = extract_identifying_suffix(entity[:uri])
            ttl_row = ["SI TTL:  #{si_suffix}", "(#{entity[:label] || entity[:name]})"]

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

        # Update references if output directory is specified
        return unless output_dir && !missing_matches.empty?

        output_file = File.join(output_dir, "#{entity_type}.yaml")
        update_references(entity_type, missing_matches, db_entities, output_file, include_potential)
        puts "\nUpdated references written to #{output_file}"
      end

      def check_to_si(entity_type, ttl_entities, db_entities, output_dir, include_potential = false)
        puts "\n=== Checking UnitsDB → SI (database entities referencing TTL) ==="

        # Print instructions for this direction
        puts "\n=== Instructions for UnitsDB → SI direction ==="
        puts "If you are the UnitsDB Register Manager, please add SI references to UnitsDB entities that should have them."
        puts "For each entity that should reference SI, add a reference with 'authority: \"si-digital-framework\"' and the SI TTL URI."

        # Find database entities that should reference TTL entities
        matches, missing_refs, unmatched_db = match_db_to_ttl(entity_type, ttl_entities, db_entities)

        # Print statistics
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
            entity_id = db_entity.short
            entity_name = db_entity.names.first if db_entity.respond_to?(:names)
            si_suffix = extract_identifying_suffix(match[:ttl_uri])

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

        # Split matches into exact and potential
        unless missing_refs.empty?
          puts "\n=== #{entity_type.capitalize} that should reference SI ==="

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
            match_desc = ""

            # Try to find match details for this entity and URI
            entity_id = match[:db_entity].short
            match_pair_key = "#{entity_id}:#{ttl_entities.first[:uri]}"
            match_details = @match_details&.dig(match_pair_key)
            match_desc = match_details[:match_desc] if match_details && match_details[:match_desc]

            # Symbol matches and partial matches should always be potential matches
            if %w[symbol_match partial_match].include?(match_desc)
              potential_matches << match
            # Otherwise categorize based on match type
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
              entity_id = db_entity.short
              entity_name = db_entity.names.first if db_entity.respond_to?(:names)

              # Handle multiple TTL entities in a single row
              ttl_entities = match[:ttl_entities]
              if ttl_entities.size == 1
                # Single TTL entity
                ttl_entity = ttl_entities.first
                si_suffix = extract_identifying_suffix(ttl_entity[:uri])

                rows << [
                  "UnitsDB: #{entity_id}",
                  "(#{entity_name})"
                ]
                rows << [
                  "SI TTL:  #{si_suffix}",
                  "(#{ttl_entity[:label] || ttl_entity[:name]})"
                ]
              else
                # Multiple TTL entities, combine them - ensure no duplicates
                si_text_parts = []
                seen_uris = {}

                ttl_entities.each do |ttl_entity|
                  uri = ttl_entity[:uri]
                  next if seen_uris[uri] # Skip if we've already seen this URI

                  seen_uris[uri] = true

                  suffix = extract_identifying_suffix(uri)
                  si_text_parts << "#{suffix} (#{ttl_entity[:label] || ttl_entity[:name]})"
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

              # Make sure we have match details for this match
              match_pair_key = "#{entity_id}:#{ttl_entities.first[:uri]}"

              # If the match details are not found, try to create them
              if !@match_details || !@match_details[match_pair_key]
                @match_details ||= {}
                match_result = match_entity_names?(entity_type, db_entity, ttl_entities.first)
                @match_details[match_pair_key] = match_result if match_result[:match]
              end

              match_details = @match_details&.dig(match_pair_key)

              # Format match info
              match_info = ""
              if match_details
                match_info = case match_details[:match_desc]
                             when "short_to_name"
                               "short → name"
                             when "short_to_label"
                               "short → label"
                             when "name_to_name"
                               "name → name"
                             when "name_to_label"
                               "name → label"
                             when "name_to_alt_label"
                               "name → alt_label"
                             when "symbol_match"
                               "symbol → symbol"
                             when "partial_match"
                               "partial match"
                             else
                               ""
                             end
              end

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
              entity_id = db_entity.short
              entity_name = db_entity.names.first if db_entity.respond_to?(:names)

              # Handle multiple TTL entities in a single row
              ttl_entities = match[:ttl_entities]
              if ttl_entities.size == 1
                # Single TTL entity
                ttl_entity = ttl_entities.first
                si_suffix = extract_identifying_suffix(ttl_entity[:uri])

                rows << [
                  "UnitsDB: #{entity_id}",
                  "(#{entity_name})"
                ]
                rows << [
                  "SI TTL:  #{si_suffix}",
                  "(#{ttl_entity[:label] || ttl_entity[:name]})"
                ]
              else
                # Multiple TTL entities, combine them - ensure no duplicates
                si_text_parts = []
                seen_uris = {}

                ttl_entities.each do |ttl_entity|
                  uri = ttl_entity[:uri]
                  next if seen_uris[uri] # Skip if we've already seen this URI

                  seen_uris[uri] = true

                  suffix = extract_identifying_suffix(uri)
                  si_text_parts << "#{suffix} (#{ttl_entity[:label] || ttl_entity[:name]})"
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

              entity_id = db_entity.short
              match_pair_key = "#{entity_id}:#{ttl_entities.first[:uri]}"

              # If the match details are not found, try to create them
              if !@match_details || !@match_details[match_pair_key]
                @match_details ||= {}
                match_result = match_entity_names?(entity_type, db_entity, ttl_entities.first)
                @match_details[match_pair_key] = match_result if match_result[:match]
              end

              match_details = @match_details&.dig(match_pair_key)

              # Format match info
              match_info = ""
              if match_details
                match_info = case match_details[:match_desc]
                             when "short_to_name"
                               "short → name"
                             when "short_to_label"
                               "short → label"
                             when "name_to_name"
                               "name → name"
                             when "name_to_label"
                               "name → label"
                             when "name_to_alt_label"
                               "name → alt_label"
                             when "symbol_match"
                               "symbol → symbol"
                             when "partial_match"
                               "partial match"
                             else
                               ""
                             end
              end

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

        # Update references if output directory is specified
        return unless output_dir && !missing_refs.empty?

        output_file = File.join(output_dir, "#{entity_type}.yaml")
        update_db_references(entity_type, missing_refs, output_file, include_potential)
        puts "\nUpdated references written to #{output_file}"
      end

      def parse_ttl_files(dir)
        puts "Parsing TTL files in #{dir}..."
        graph = RDF::Graph.new

        # Find all TTL files in the references directory
        ttl_files = Dir.glob(File.join(dir, "*.ttl"))
        ttl_files.each do |file|
          puts "  Reading #{File.basename(file)}"
          graph.load(file, format: :ttl)
        end

        graph
      end

      def extract_entities_from_ttl(entity_type, graph)
        # Define prefixes used in the TTL files
        skos = RDF::Vocabulary.new("http://www.w3.org/2004/02/skos/core#")
        si = RDF::Vocabulary.new("http://si-digital-framework.org/SI#")

        case entity_type
        when "units"
          namespace = RDF::Vocabulary.new("http://si-digital-framework.org/SI/units/")
          extract_with_symbols(graph, namespace, skos, si)
        when "quantities"
          namespace = RDF::Vocabulary.new("http://si-digital-framework.org/quantities/")
          extract_entities(graph, namespace, skos)
        when "prefixes"
          namespace = RDF::Vocabulary.new("http://si-digital-framework.org/SI/prefixes/")
          extract_with_symbols(graph, namespace, skos, si)
        else
          []
        end
      end

      def extract_entities(graph, namespace, skos)
        entities = []
        processed_uris = {} # Track processed URIs to avoid duplicates

        # Find all subjects with skos:prefLabel
        RDF::Query.new(
          { entity: { skos.prefLabel => :label } }
        ).execute(graph).each do |solution|
          entity_uri = solution.entity.to_s

          # Only process entities in the specified namespace and avoid duplicates
          next unless entity_uri.start_with?(namespace.to_s)
          next if processed_uris[entity_uri] # Skip if we've already processed this URI

          processed_uris[entity_uri] = true # Mark as processed

          # Get the label
          label_solution = RDF::Query.new(
            { RDF::URI(entity_uri) => { skos.prefLabel => :label } }
          ).execute(graph).first

          # Get alternative label if available
          alt_label_solution = RDF::Query.new(
            { RDF::URI(entity_uri) => { skos.altLabel => :alt_label } }
          ).execute(graph).first

          entity_name = entity_uri.split("/").last
          label = label_solution&.label&.to_s
          alt_label = alt_label_solution&.alt_label&.to_s

          entities << {
            uri: entity_uri,
            name: entity_name,
            label: label,
            alt_label: alt_label
          }
        end

        entities
      end

      def extract_with_symbols(graph, namespace, skos, si)
        entities = extract_entities(graph, namespace, skos)

        # Add symbols for units and prefixes
        entities.each do |entity|
          # Get the symbol if available
          symbol_solution = RDF::Query.new(
            { RDF::URI(entity[:uri]) => { si.hasSymbol => :symbol } }
          ).execute(graph).first

          entity[:symbol] = symbol_solution&.symbol&.to_s if symbol_solution
        end

        entities
      end

      # Match TTL entities to database entities (from_si direction)
      def match_ttl_to_db(entity_type, ttl_entities, db_entities)
        matches = []
        missing_matches = []
        matched_ttl_uris = []
        processed_pairs = {} # Track processed entity-ttl pairs to avoid duplicates

        # Track matches by entity ID to group multiple SI matches for the same entity
        entity_matches = {}
        match_types = {}

        # First pass: find all direct references to TTL entities in database entities
        # This ensures that any TTL entity directly referenced is marked as matched
        db_entities.each do |entity|
          next unless entity.respond_to?(:references) && entity.references

          entity.references.each do |ref|
            next unless ref.authority == "si-digital-framework"

            # Add this URI to the matched TTL URIs
            matched_ttl_uris << ref.uri

            # Find the corresponding TTL entity
            ttl_entity = ttl_entities.find { |e| e[:uri] == ref.uri }
            next unless ttl_entity

            # Get entity info
            entity_id = entity.short
            entity_name = entity.names.first if entity.respond_to?(:names)

            # Add to matches
            matches << {
              entity_id: entity_id,
              entity_name: entity_name,
              si_uri: ttl_entity[:uri],
              si_name: ttl_entity[:name],
              si_label: ttl_entity[:label],
              si_alt_label: ttl_entity[:alt_label],
              si_symbol: ttl_entity[:symbol],
              entity: entity
            }
          end
        end

        # Second pass: find matching entities based on names and symbols
        ttl_entities.each do |ttl_entity|
          # Skip if already matched by direct reference
          next if matched_ttl_uris.include?(ttl_entity[:uri])

          # Find matching entities in the database using exact matching only
          matching_entities = find_matching_entities(entity_type, ttl_entity, db_entities)

          next if matching_entities.empty?

          matched_ttl_uris << ttl_entity[:uri]

          matching_entities.each do |entity|
            # Get entity ID
            entity_id = entity.short
            entity_name = entity.names.first if entity.respond_to?(:names)

            # Create a unique key for this entity-ttl pair to avoid duplicates
            pair_key = "#{entity_id}:#{ttl_entity[:uri]}"
            next if processed_pairs[pair_key]

            processed_pairs[pair_key] = true

            # Get detailed match information
            match_result = match_entity_names?(entity_type, entity, ttl_entity)
            next unless match_result[:match]

            # Save match type and details for later use
            match_types[pair_key] = match_result[:match_type]
            @match_details ||= {}
            @match_details[pair_key] = match_result

            # Check if this entity already has a reference to SI digital framework
            has_reference = entity.references&.any? do |ref|
              ref.uri == ttl_entity[:uri] && ref.authority == "si-digital-framework"
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
              match_details: match_result
            }

            if has_reference
              matches << match_data
            else
              # Group by entity_id to handle multiple SI matches for one entity
              entity_matches[entity_id] ||= []
              entity_matches[entity_id] << {
                uri: ttl_entity[:uri],
                name: ttl_entity[:name],
                label: ttl_entity[:label]
              }

              # If this is our first encounter with this entity, save its full match data
              missing_matches << match_data unless missing_matches.any? { |m| m[:entity_id] == entity_id }
            end
          end
        end

        # Update missing_matches to include multiple SI entities when needed
        missing_matches.each do |match|
          entity_id = match[:entity_id]
          si_matches = entity_matches[entity_id]

          # If an entity matches multiple SI entities, record them
          match[:multiple_si] = si_matches if si_matches && si_matches.size > 1
        end

        # Find unmatched TTL entities - filter out base namespace URI (units/, quantities/, prefixes/)
        unmatched_ttl = ttl_entities.reject do |entity|
          matched_ttl_uris.include?(entity[:uri]) ||
            # Exclude base namespace URIs like "http://si-digital-framework.org/SI/units/"
            entity[:uri].end_with?("/units/") || entity[:uri].end_with?("/quantities/") || entity[:uri].end_with?("/prefixes/")
        end

        [matches, missing_matches, unmatched_ttl]
      end

      # Match database entities to TTL entities (to_si direction)
      def match_db_to_ttl(entity_type, ttl_entities, db_entities)
        matches = []
        missing_refs = []
        matched_db_ids = []
        processed_db_ids = {} # To avoid processing the same entity multiple times

        db_entities.each do |db_entity|
          entity_id = find_entity_id(db_entity)

          # Skip if we've already processed this entity
          next if processed_db_ids[entity_id]

          processed_db_ids[entity_id] = true

          # Check first if this entity has a reference to any TTL entity
          # This is important - if there's already a si-digital-framework reference,
          # we consider it a valid mapping
          has_si_reference = false
          if db_entity.respond_to?(:references) && db_entity.references
            db_entity.references.each do |ref|
              next unless ref.authority == "si-digital-framework"

              has_si_reference = true
              # Find the matching TTL entity for better display
              matching_ttl_entity = ttl_entities.find { |e| e[:uri] == ref.uri }

              matches << {
                entity_id: entity_id,
                db_entity: db_entity,
                ttl_uri: ref.uri,
                ttl_entity: matching_ttl_entity
              }
            end
          end

          # If already has reference, continue to next entity
          if has_si_reference
            matched_db_ids << entity_id
            next
          end

          # If no reference found, try to find matching TTL entity by name/symbol
          matching_ttl = []
          match_types = {}

          ttl_entities.each do |ttl_entity|
            match_result = match_entity_names?(entity_type, db_entity, ttl_entity)
            next unless match_result[:match]

            matching_ttl << ttl_entity
            match_types[ttl_entity[:uri]] = match_result[:match_type]
            # Save the detailed match info for display
            @match_details ||= {}
            @match_details["#{entity_id}:#{ttl_entity[:uri]}"] = match_result
          end

          # If found matches, add to missing_refs
          next if matching_ttl.empty?

          matched_db_ids << entity_id
          # Store all matching TTL entities together with this db entity
          missing_refs << {
            entity_id: entity_id,
            db_entity: db_entity,
            ttl_entities: matching_ttl,
            match_types: match_types
          }
        end

        # Find unmatched db entities
        unmatched_db = db_entities.reject { |entity| matched_db_ids.include?(find_entity_id(entity)) }

        [matches, missing_refs, unmatched_db]
      end

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

      # Find exact matches only for units
      def find_matching_units(ttl_unit, units)
        matching_units = []

        # Try exact match by short
        units.each do |unit|
          if unit.short&.downcase == ttl_unit[:name]&.downcase ||
             unit.short&.downcase == ttl_unit[:label]&.downcase
            matching_units << unit
            next
          end

          # Try exact match by name
          if unit.respond_to?(:names) && unit.names&.any? do |name|
            name.downcase == ttl_unit[:name]&.downcase ||
            name.downcase == ttl_unit[:label]&.downcase
          end
            matching_units << unit
            next
          end

          # Try exact match by symbol
          next unless ttl_unit[:symbol] && unit.respond_to?(:symbols) && unit.symbols&.any? do |sym|
            sym.respond_to?(:ascii) && sym.ascii && sym.ascii.downcase == ttl_unit[:symbol].downcase
          end

          matching_units << unit
        end

        matching_units.uniq
      end

      # Find exact matches only for quantities
      def find_matching_quantities(ttl_quantity, quantities)
        matching_quantities = []

        # Try exact match by short
        quantities.each do |quantity|
          if quantity.short&.downcase == ttl_quantity[:name]&.downcase ||
             quantity.short&.downcase == ttl_quantity[:label]&.downcase ||
             quantity.short&.downcase == ttl_quantity[:alt_label]&.downcase
            matching_quantities << quantity
            next
          end

          # Try exact match by name
          next unless quantity.respond_to?(:names) && quantity.names&.any? do |name|
            name.downcase == ttl_quantity[:name]&.downcase ||
            name.downcase == ttl_quantity[:label]&.downcase ||
            name.downcase == ttl_quantity[:alt_label]&.downcase
          end

          matching_quantities << quantity
        end

        matching_quantities.uniq
      end

      # Find exact matches only for prefixes
      def find_matching_prefixes(ttl_prefix, prefixes)
        matching_prefixes = []

        # Try exact match by short
        prefixes.each do |prefix|
          if prefix.short&.downcase == ttl_prefix[:name]&.downcase ||
             prefix.short&.downcase == ttl_prefix[:label]&.downcase
            matching_prefixes << prefix
            next
          end

          # Try exact match by name
          if prefix.respond_to?(:names) && prefix.names&.any? do |name|
            name.downcase == ttl_prefix[:name]&.downcase ||
            name.downcase == ttl_prefix[:label]&.downcase
          end
            matching_prefixes << prefix
            next
          end

          # Try exact match by symbol
          next unless ttl_prefix[:symbol] && prefix.respond_to?(:symbol) && prefix.symbol &&
                      prefix.symbol.respond_to?(:ascii) && prefix.symbol.ascii &&
                      prefix.symbol.ascii.downcase == ttl_prefix[:symbol].downcase

          matching_prefixes << prefix
        end

        matching_prefixes.uniq
      end

      # Match entity names with exact matching only
      def match_entity_names?(entity_type, db_entity, ttl_entity)
        match_details = { match: false }

        # Match by short name - EXACT match only (case insensitive)
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

        # Match by names - EXACT match only (case insensitive)
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

        # More strict validation for "sidereal_" units
        # If the short has "sidereal_" prefix but the matched TTL entity doesn't have "sidereal" in name/label
        if match_details[:match] && match_details[:exact] && (db_entity.short&.include?("sidereal_") &&
                     !(ttl_entity[:name]&.include?("sidereal") || ttl_entity[:label]&.include?("sidereal")))
          match_details = {
            match: true,
            exact: false,
            match_type: "Potential match",
            match_desc: "partial_match",
            details: "UnitsDB '#{db_entity.short}' partially matches SI '#{ttl_entity[:name]}'"
          }
        end

        # Match by symbol if available (units and prefixes) - POTENTIAL match only
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

      def update_references(entity_type, missing_matches, _entities, output_file, include_potential = false)
        # Get path to original YAML file
        fixture_dir = File.expand_path(File.join(__dir__, "../../../spec/fixtures/unitsdb"))
        original_yaml_file = File.join(fixture_dir, "#{entity_type}.yaml")

        # Load the original YAML file
        yaml_content = File.read(original_yaml_file)
        output_data = YAML.safe_load(yaml_content)

        # Group by entity ID to avoid duplicates
        grouped_matches = missing_matches.group_by { |match| match[:entity_id] }

        # Process each entity that needs updating
        grouped_matches.each do |entity_id, matches|
          # Filter matches based on include_potential parameter
          filtered_matches = matches.select do |match|
            # Check if it's an exact match or if we're including potential matches
            match_type = "Exact match" # Default
            if match[:match_types] && !match[:match_types].empty?
              uri = match[:si_uri]
              match_type = match[:match_types][uri] if match[:match_types][uri]
            end

            # Only include exact matches unless include_potential is true
            match_type == "Exact match" || include_potential
          end

          # Skip if no matches after filtering
          next if filtered_matches.empty?

          # Find the entity in the array under the entity_type key
          entity_index = output_data[entity_type].find_index do |e|
            # Find entity with matching identifier
            e["identifiers"]&.any? { |id| id["id"] == entity_id }
          end

          next unless entity_index

          # Get the entity
          entity = output_data[entity_type][entity_index]

          # Initialize references array if it doesn't exist
          entity["references"] ||= []

          # Add new references
          matches.each do |match|
            # If this match has multiple SI references, add them all
            if match[:multiple_si]
              match[:multiple_si].each do |si_data|
                # Check if reference already exists
                next if entity["references"].any? do |ref|
                  ref["uri"] == si_data[:uri] && ref["authority"] == "si-digital-framework"
                end

                # Add new reference
                entity["references"] << {
                  "uri" => si_data[:uri],
                  "type" => "normative",
                  "authority" => "si-digital-framework"
                }
              end
            else
              # Check if reference already exists
              next if entity["references"].any? do |ref|
                ref["uri"] == match[:si_uri] && ref["authority"] == "si-digital-framework"
              end

              # Add new reference
              entity["references"] << {
                "uri" => match[:si_uri],
                "type" => "normative",
                "authority" => "si-digital-framework"
              }
            end
          end
        end

        # Ensure the output directory exists
        output_dir = File.dirname(output_file)
        FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

        # Write to YAML file
        File.write(output_file, output_data.to_yaml)
      end

      def update_db_references(entity_type, missing_refs, output_file, include_potential = false)
        # Get path to original YAML file
        fixture_dir = File.expand_path(File.join(__dir__, "../../../spec/fixtures/unitsdb"))
        original_yaml_file = File.join(fixture_dir, "#{entity_type}.yaml")

        # Load the original YAML file
        yaml_content = File.read(original_yaml_file)
        output_data = YAML.safe_load(yaml_content)

        # Group by entity ID to avoid duplicates
        missing_refs_by_id = {}

        missing_refs.each do |match|
          entity_id = match[:entity_id]
          ttl_entities = match[:ttl_entities]
          match_types = match[:match_types] || {}

          # Filter TTL entities based on include_potential parameter
          filtered_ttl_entities = ttl_entities.select do |ttl_entity|
            # Check if it's an exact match or if we're including potential matches
            match_type = match_types[ttl_entity[:uri]] || "Exact match" # Default to exact match
            match_type == "Exact match" || include_potential
          end

          # Skip if no entities after filtering
          next if filtered_ttl_entities.empty?

          missing_refs_by_id[entity_id] ||= []

          # Add filtered matching TTL entities for this DB entity
          filtered_ttl_entities.each do |ttl_entity|
            missing_refs_by_id[entity_id] << {
              uri: ttl_entity[:uri],
              type: "normative",
              authority: "si-digital-framework"
            }
          end
        end

        # Update the YAML content
        output_data[entity_type].each do |entity_yaml|
          # Find entity by ID or short
          entity_id = if entity_yaml["identifiers"]
                        begin
                          entity_yaml["identifiers"].first["id"]
                        rescue StandardError
                          nil
                        end
                      elsif entity_yaml["id"]
                        entity_yaml["id"]
                      end

          next unless entity_id && missing_refs_by_id.key?(entity_id)

          # Add references
          entity_yaml["references"] ||= []

          missing_refs_by_id[entity_id].each do |ref|
            # Check if this reference already exists
            next if entity_yaml["references"].any? do |existing_ref|
              existing_ref["uri"] == ref[:uri] &&
              existing_ref["authority"] == ref[:authority]
            end

            # Add the reference
            entity_yaml["references"] << {
              "uri" => ref[:uri],
              "type" => ref[:type],
              "authority" => ref[:authority]
            }
          end
        end

        # Ensure the output directory exists
        output_dir = File.dirname(output_file)
        FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

        # Write to YAML file
        File.write(output_file, output_data.to_yaml)
      end

      def find_entity_id(entity)
        return entity.id if entity.respond_to?(:id) && entity.id
        return entity.identifiers.first.id if !entity.identifiers.empty? &&
                                              entity.identifiers.first.respond_to?(:id)

        entity.short
      end
    end
  end
end
