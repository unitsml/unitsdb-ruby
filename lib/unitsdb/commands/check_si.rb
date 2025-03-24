# frozen_string_literal: true

require "rdf"
require "rdf/turtle"
require "yaml"
require "fileutils"
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

        # Parse all TTL files once
        graph = parse_ttl_files(ttl_dir)

        # Process entity types
        if entity_type && ENTITY_TYPES.include?(entity_type)
          # Process only the specified entity type
          process_entity_type(entity_type, @db, graph, direction, output_dir)
        else
          # Process all entity types
          ENTITY_TYPES.each do |type|
            process_entity_type(type, @db, graph, direction, output_dir)
          end
        end
      end

      private

      def process_entity_type(entity_type, db, graph, direction, output_dir)
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

        check_to_si(entity_type, ttl_entities, db_entities, output_dir)
      end

      def check_from_si(entity_type, ttl_entities, db_entities, output_dir)
        puts "\n=== Checking SI → UnitsDB (TTL entities referenced by database) ==="

        # Find TTL entities referenced by database entities
        matches, missing_matches, unmatched_ttl = match_ttl_to_db(entity_type, ttl_entities, db_entities)

        # Print results
        puts "\n=== #{entity_type.capitalize} with matching SI references ==="
        if matches.empty?
          puts "None"
        else
          matches.each do |match|
            puts "✓ #{match[:entity_id]} (#{match[:entity_name]}) -> #{match[:si_uri]}"
          end
        end

        puts "\n=== #{entity_type.capitalize} without SI references ==="
        if missing_matches.empty?
          puts "None"
        else
          missing_matches.each do |match|
            puts "✗ #{match[:entity_id]} (#{match[:entity_name]}) -> #{match[:si_uri]} (missing reference)"
          end
        end

        puts "\n=== SI #{entity_type.capitalize} not mapped to our database ==="
        if unmatched_ttl.empty?
          puts "None (All TTL entities are referenced - Good job!)"
        else
          unmatched_ttl.each do |entity|
            puts "? #{entity[:name]} (#{entity[:label]}) -> #{entity[:uri]}"
          end
        end

        # Update references if output directory is specified
        return unless output_dir && !missing_matches.empty?

        output_file = File.join(output_dir, "#{entity_type}.yaml")
        update_references(entity_type, missing_matches, db_entities, output_file)
        puts "\nUpdated references written to #{output_file}"
      end

      def check_to_si(entity_type, ttl_entities, db_entities, output_dir)
        puts "\n=== Checking UnitsDB → SI (database entities referencing TTL) ==="

        # Find database entities that should reference TTL entities
        matches, missing_refs, unmatched_db = match_db_to_ttl(entity_type, ttl_entities, db_entities)

        # Print statistics
        puts "\n=== Summary of database entities referencing SI ==="
        puts "#{entity_type.capitalize} with SI references: #{matches.size}"
        puts "#{entity_type.capitalize} missing SI references: #{missing_refs.size}"
        puts "Database #{entity_type} not matching any SI entity: #{unmatched_db.size}"

        # Show entities missing references
        unless missing_refs.empty?
          puts "\n=== #{entity_type.capitalize} that should reference SI ==="
          missing_refs.each do |match|
            db_entity = match[:db_entity]
            entity_id = db_entity.short
            entity_name = db_entity.names.first if db_entity.respond_to?(:names)
            puts "✗ #{entity_id} (#{entity_name}) -> #{match[:ttl_entity][:uri]}"
          end
        end

        # Update references if output directory is specified
        return unless output_dir && !missing_refs.empty?

        output_file = File.join(output_dir, "#{entity_type}.yaml")
        update_db_references(entity_type, missing_refs, output_file)
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

        # Find all subjects with skos:prefLabel
        RDF::Query.new(
          { entity: { skos.prefLabel => :label } }
        ).execute(graph).each do |solution|
          entity_uri = solution.entity.to_s

          # Only process entities in the specified namespace
          next unless entity_uri.start_with?(namespace.to_s)

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

        ttl_entities.each do |ttl_entity|
          # Find matching entities in the database
          matching_entities = find_matching_entities(entity_type, ttl_entity, db_entities)

          next if matching_entities.empty?

          matched_ttl_uris << ttl_entity[:uri]

          matching_entities.each do |entity|
            # Get entity ID
            entity_id = entity.short
            entity_name = entity.names.first if entity.respond_to?(:names)

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
              entity: entity
            }

            if has_reference
              matches << match_data
            else
              missing_matches << match_data
            end
          end
        end

        # Find unmatched TTL entities
        unmatched_ttl = ttl_entities.reject { |entity| matched_ttl_uris.include?(entity[:uri]) }

        [matches, missing_matches, unmatched_ttl]
      end

      # Match database entities to TTL entities (to_si direction)
      def match_db_to_ttl(entity_type, ttl_entities, db_entities)
        matches = []
        missing_refs = []
        matched_db_ids = []

        db_entities.each do |db_entity|
          entity_id = find_entity_id(db_entity)

          # Try to find matching TTL entity
          matching_ttl = []

          # Check first if this entity has a reference to any TTL entity
          has_si_reference = false
          if db_entity.respond_to?(:references) && db_entity.references
            db_entity.references.each do |ref|
              next unless ref.authority == "si-digital-framework"

              has_si_reference = true
              matches << {
                entity_id: entity_id,
                db_entity: db_entity,
                ttl_uri: ref.uri
              }
              break
            end
          end

          # If already has reference, continue to next entity
          if has_si_reference
            matched_db_ids << entity_id
            next
          end

          # Try to find matching TTL entity by name/symbol
          ttl_entities.each do |ttl_entity|
            matching_ttl << ttl_entity if match_entity_names?(entity_type, db_entity, ttl_entity)
          end

          # If found matches, add to missing_refs
          next if matching_ttl.empty?

          matched_db_ids << entity_id
          matching_ttl.each do |ttl_entity|
            missing_refs << {
              entity_id: entity_id,
              db_entity: db_entity,
              ttl_entity: ttl_entity
            }
          end
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

      def find_matching_units(ttl_unit, _units)
        # Match by name or label
        matching_units = @db.search(text: ttl_unit[:name], type: "units")
        matching_units += @db.search(text: ttl_unit[:label], type: "units") if ttl_unit[:label]

        # If no match by name, try by symbol
        if matching_units.empty? && ttl_unit[:symbol]
          matching_units = _units.select do |unit|
            unit.symbols&.any? { |sym| sym.ascii&.downcase == ttl_unit[:symbol]&.downcase }
          end
        end

        matching_units.uniq
      end

      def find_matching_quantities(ttl_quantity, _quantities)
        # Match by name, label, or alt_label
        matching_quantities = @db.search(text: ttl_quantity[:name], type: "quantities")
        matching_quantities += @db.search(text: ttl_quantity[:label], type: "quantities") if ttl_quantity[:label]
        if ttl_quantity[:alt_label]
          matching_quantities += @db.search(text: ttl_quantity[:alt_label],
                                            type: "quantities")
        end

        matching_quantities.uniq
      end

      def find_matching_prefixes(ttl_prefix, _prefixes)
        # Match by name or label
        matching_prefixes = @db.search(text: ttl_prefix[:name], type: "prefixes")
        matching_prefixes += @db.search(text: ttl_prefix[:label], type: "prefixes") if ttl_prefix[:label]

        # If no match by name, try by symbol
        if matching_prefixes.empty? && ttl_prefix[:symbol]
          matching_prefixes = _prefixes.select do |prefix|
            prefix.symbol&.ascii&.downcase == ttl_prefix[:symbol]&.downcase
          end
        end

        matching_prefixes.uniq
      end

      def match_entity_names?(entity_type, db_entity, ttl_entity)
        # Match by short name (case insensitive)
        return true if db_entity.short && db_entity.short.downcase == ttl_entity[:name].downcase

        # Match by ID
        return true if db_entity.identifiers&.any? do |id|
          id.respond_to?(:id) && id.id.downcase == ttl_entity[:name].downcase
        end

        # Match by label if available
        if ttl_entity[:label] && db_entity.respond_to?(:names) && db_entity.names&.any? do |name|
          name.downcase == ttl_entity[:label].downcase
        end
          return true
        end

        # Match by alt label if available
        if ttl_entity[:alt_label] && db_entity.respond_to?(:names) && db_entity.names&.any? do |name|
          name.downcase == ttl_entity[:alt_label].downcase
        end
          return true
        end

        # Match by symbol if available (units and prefixes)
        if %w[units prefixes].include?(entity_type) && ttl_entity[:symbol]
          if entity_type == "units" && db_entity.respond_to?(:symbols) && db_entity.symbols
            return true if db_entity.symbols.any? do |sym|
              sym.respond_to?(:ascii) && sym.ascii && sym.ascii.downcase == ttl_entity[:symbol].downcase
            end
          elsif entity_type == "prefixes" && db_entity.respond_to?(:symbol) && db_entity.symbol
            return db_entity.symbol.respond_to?(:ascii) &&
                   db_entity.symbol.ascii &&
                   db_entity.symbol.ascii.downcase == ttl_entity[:symbol].downcase
          end
        end

        false
      end

      def update_references(entity_type, missing_matches, _entities, output_file)
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

        # Ensure the output directory exists
        output_dir = File.dirname(output_file)
        FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

        # Write to YAML file
        File.write(output_file, output_data.to_yaml)
      end

      def update_db_references(entity_type, missing_refs, output_file)
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
          ttl_entity = match[:ttl_entity]

          missing_refs_by_id[entity_id] ||= []
          missing_refs_by_id[entity_id] << {
            uri: ttl_entity[:uri],
            type: "normative",
            authority: "si-digital-framework"
          }
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
