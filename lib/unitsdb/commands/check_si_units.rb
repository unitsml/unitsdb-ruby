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
    class CheckSiUnits < Base
      # Entity types supported by this command
      ENTITY_TYPES = %w[units quantities prefixes].freeze

      desc "check", "Check entities in SI digital framework against UnitsDB content"
      option :entity_type, type: :string, aliases: "-e",
                           desc: "Entity type to check (units, quantities, prefixes). Defaults to units."
      option :output, type: :string, aliases: "-o",
                      desc: "Output file path for updated YAML file"
      option :ttl_dir, type: :string, required: true, aliases: "-t",
                       desc: "Path to the directory containing SI digital framework TTL files"

      def check(options = {})
        # Get key options
        entity_type = options[:entity_type] || "units"
        database_path = options[:database]
        ttl_dir = options[:ttl_dir]

        # Validate entity type first, before any other operations
        unless ENTITY_TYPES.include?(entity_type)
          puts "Invalid entity type: #{entity_type}. Must be one of: #{ENTITY_TYPES.join(", ")}"
          exit(1)
        end

        # Calculate output file path or use default if database_path is missing
        output_file = options[:output]
        output_file ||= database_path ? File.join(database_path, "#{entity_type}.yaml") : "#{entity_type}.yaml"

        puts "Using database directory: #{database_path}"
        puts "Checking entity type: #{entity_type}"

        # Validate ttl_dir is provided
        if ttl_dir.nil?
          puts "Error: TTL directory is required"
          exit(1)
        end

        puts "Using TTL directory: #{ttl_dir}"

        # Verify TTL directory exists
        raise Unitsdb::Errors::DatabaseNotFoundError, "TTL directory not found: #{ttl_dir}" unless Dir.exist?(ttl_dir)

        # Load database
        database = load_database(database_path)
        db_entities = database.send(entity_type)
        puts "Found #{db_entities.size} #{entity_type} in database"

        # Determine TTL file name for the entity type
        ttl_filename = case entity_type
                       when "units" then "units.ttl"
                       when "quantities" then "quantities.ttl"
                       when "prefixes" then "prefixes.ttl"
                       end

        # Parse RDF
        ttl_path = File.join(ttl_dir, ttl_filename)
        raise Unitsdb::Errors::DatabaseFileNotFoundError, "TTL file not found: #{ttl_path}" unless File.exist?(ttl_path)

        puts "Parsing TTL file: #{ttl_path}"
        ttl_entities = parse_ttl(ttl_path, entity_type)
        puts "Found #{ttl_entities.size} #{entity_type} in SI digital framework"

        # Match entities and check references
        matches, missing_refs, unmatched_ttl = match_entities(entity_type, ttl_entities, db_entities)

        # Print statistics
        puts "\n=== Summary ==="
        puts "#{entity_type.capitalize} with SI references: #{matches.size}"
        puts "#{entity_type.capitalize} missing SI references: #{missing_refs.size}"
        puts "SI #{entity_type} not found in our database: #{unmatched_ttl.size}"

        # Show entities missing references
        unless missing_refs.empty?
          puts "\n=== #{entity_type.capitalize} missing SI references ==="
          missing_refs.each do |match|
            db_entity = match[:db_entity]
            entity_name = db_entity.short || db_entity.respond_to?(:id) ? db_entity.id : "Unknown"
            puts "✗ #{entity_name} -> #{match[:ttl_entity][:uri]}"
          end
        end

        # Show SI entities not found in our database
        unless unmatched_ttl.empty?
          puts "\n=== SI #{entity_type.capitalize} not found in our database ==="
          unmatched_ttl.each do |entity|
            puts "? #{entity[:name]} (#{entity[:label] || "No label"}) -> #{entity[:uri]}"
          end
        end

        # If no missing references, we're done
        if missing_refs.empty?
          puts "\nNo missing references found. All #{entity_type} have SI references."
          return
        end

        # Update YAML and write to file
        update_yaml(database_path, entity_type, missing_refs, output_file)
        puts "\nUpdated YAML written to #{output_file}"
      end

      private

      def parse_ttl(file_path, entity_type)
        graph = RDF::Graph.new
        graph.from_file(file_path, format: :ttl)

        # Define prefixes used in the TTL file
        skos = RDF::Vocabulary.new("http://www.w3.org/2004/02/skos/core#")
        si = RDF::Vocabulary.new("http://si-digital-framework.org/SI#")

        # Determine namespace based on entity type
        namespace = case entity_type
                    when "units"
                      RDF::Vocabulary.new("http://si-digital-framework.org/SI/units/")
                    when "quantities"
                      RDF::Vocabulary.new("http://si-digital-framework.org/quantities/")
                    when "prefixes"
                      RDF::Vocabulary.new("http://si-digital-framework.org/SI/prefixes/")
                    end

        result = []

        # Extract entities from the graph
        RDF::Query.new({ entity: { skos.prefLabel => :label } }).execute(graph).each do |solution|
          entity_uri = solution.entity.to_s

          # Only process entities in the correct namespace
          next unless entity_uri.start_with?(namespace.to_s)

          # Get label
          label = solution.label.to_s if solution.label

          # Get alt label if available
          alt_label_solution = RDF::Query.new(
            { RDF::URI(entity_uri) => { skos.altLabel => :alt_label } }
          ).execute(graph).first
          alt_label = alt_label_solution&.alt_label&.to_s

          # Get symbol if applicable (for units and prefixes)
          symbol = nil
          if %w[units prefixes].include?(entity_type)
            symbol_query = RDF::Query.new({ RDF::URI(entity_uri) => { si.hasSymbol => :symbol } })
            symbol_solution = symbol_query.execute(graph).first
            symbol = symbol_solution&.symbol&.to_s
          end

          # Extract entity name from URI
          entity_name = entity_uri.split("/").last

          result << {
            uri: entity_uri,
            name: entity_name,
            label: label,
            alt_label: alt_label,
            symbol: symbol
          }
        end

        result
      end

      def match_entities(entity_type, ttl_entities, db_entities)
        matches = []
        missing_refs = []
        matched_ttl_uris = []

        ttl_entities.each do |ttl_entity|
          # Find matching entities in the database
          matching_db_entities = find_matching_entities(entity_type, ttl_entity, db_entities)

          # If no matches were found, add to unmatched list
          next if matching_db_entities.empty?

          # Record that this TTL entity was matched
          matched_ttl_uris << ttl_entity[:uri]

          # Check each matching entity for references
          matching_db_entities.each do |db_entity|
            # Check if this entity already has a reference to the TTL
            has_reference = entity_has_reference?(db_entity, ttl_entity[:uri])

            # Create match data record
            match_data = {
              entity_id: find_entity_id(db_entity),
              db_entity: db_entity,
              ttl_entity: ttl_entity
            }

            # Add to appropriate list
            if has_reference
              matches << match_data
            else
              missing_refs << match_data
            end
          end
        end

        # Find unmatched TTL entities
        unmatched_ttl = ttl_entities.reject { |entity| matched_ttl_uris.include?(entity[:uri]) }

        [matches, missing_refs, unmatched_ttl]
      end

      def find_matching_entities(entity_type, ttl_entity, db_entities)
        matching_entities = []

        db_entities.each do |db_entity|
          # Match based on entity type
          matching_entities << db_entity if match_entity_names?(entity_type, db_entity, ttl_entity)
        end

        matching_entities
      end

      def match_entity_names?(entity_type, db_entity, ttl_entity)
        # Match by short name (case insensitive)
        return true if db_entity.short && db_entity.short.downcase == ttl_entity[:name].downcase

        # Match by ID
        return true if db_entity.identifiers && db_entity.identifiers.any? do |id|
          id.respond_to?(:id) && id.id.downcase == ttl_entity[:name].downcase
        end

        # Match by label if available
        if ttl_entity[:label] && db_entity.respond_to?(:names) && db_entity.names && db_entity.names.any? do |name|
          name.downcase == ttl_entity[:label].downcase
        end
          return true
        end

        # Match by alt label if available
        if ttl_entity[:alt_label] && db_entity.respond_to?(:names) && db_entity.names && db_entity.names.any? do |name|
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

      def entity_has_reference?(entity, uri)
        entity.respond_to?(:references) &&
          entity.references &&
          entity.references.any? do |ref|
            ref.uri == uri && ref.authority == "si-digital-framework"
          end
      end

      def update_yaml(database_path, entity_type, missing_refs, output_file)
        # Load the original YAML file
        yaml_file = File.join(database_path, "#{entity_type}.yaml")
        yaml_content = YAML.safe_load(File.read(yaml_file))

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
        yaml_content[entity_type].each do |entity_yaml|
          # Find entity by ID or short
          entity_id = if entity_yaml["identifiers"]
                        begin
                          entity_yaml["identifiers"].first["id"]
                        rescue StandardError
                          nil
                        end
                      elsif entity_yaml["id"]
                        entity_yaml["id"]
                      else
                        nil
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

        # Write the updated YAML to the output file
        FileUtils.mkdir_p(File.dirname(output_file)) unless Dir.exist?(File.dirname(output_file))
        File.write(output_file, yaml_content.to_yaml)
      end

      def find_entity_id(entity)
        return entity.id if entity.respond_to?(:id) && entity.id
        return entity.identifiers.first.id if entity.identifiers && entity.identifiers.first &&
                                              entity.identifiers.first.respond_to?(:id)

        entity.short
      end
    end
  end
end
