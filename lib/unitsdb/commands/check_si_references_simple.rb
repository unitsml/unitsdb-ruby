# frozen_string_literal: true

require "rdf"
require "rdf/turtle"
require "yaml"
require "fileutils"
require_relative "../database"
require_relative "../external_reference"

module Unitsdb
  module Commands
    class CheckSiReferencesSimple
      # Entity types supported by this command
      ENTITY_TYPES = %w[units quantities prefixes].freeze

      def check(options = {})
        entity_type = options[:entity_type] || "units"
        fixture_dir = File.expand_path(File.join(File.dirname(__FILE__), "../../../spec/fixtures/unitsdb"))
        references_dir = File.expand_path(File.join(File.dirname(__FILE__), "../../../references"))

        puts "Using fixture directory: #{fixture_dir}"
        puts "Using references directory: #{references_dir}"

        # Load database from fixture directory
        puts "Loading database from: #{fixture_dir}"
        @db = Unitsdb::Database.from_db(fixture_dir)

        # Get entities for the specified type
        yaml_file = File.join(fixture_dir, "#{entity_type}.yaml")
        entities_collection = @db.send(entity_type)

        # Find TTL files
        ttl_files = Dir.glob(File.join(references_dir, "*.ttl"))
        puts "Found TTL files: #{ttl_files.map { |f| File.basename(f) }.join(", ")}"

        # Parse TTL files
        graph = RDF::Graph.new
        ttl_files.each do |file|
          puts "  Reading #{File.basename(file)}"
          begin
            # Parse the TTL file and add to graph
            RDF::Reader.open(file, format: :ttl) do |reader|
              reader.each_statement do |statement|
                graph << statement
              end
            end
          rescue StandardError => e
            puts "Error reading #{file}: #{e.message}"
          end
        end

        # Extract units from TTL
        ttl_units = extract_entities(entity_type, graph)
        puts "Found #{ttl_units.size} #{entity_type} in TTL files"

        # Process entities from the database
        missing_refs = []

        entities_collection.each do |entity_data|
          entity_id = entity_data.names.first
          entity_short = entity_data.short

          # Try to find matching TTL entity
          matching_ttl_entities = find_matching_entities(entity_type, entity_short, ttl_units)
          next if matching_ttl_entities.empty?

          # Check if entity already has the SI reference
          has_reference = false
          if entity_data.references
            entity_data.references.each do |ref|
              if ref.authority == "si-digital-framework"
                has_reference = true
                break
              end
            end
          end

          next if has_reference

          # Store missing reference
          matching_ttl_entities.each do |ttl_entity|
            missing_refs << {
              entity_id: entity_id,
              entity_short: entity_short,
              si_uri: ttl_entity[:uri]
            }
            puts "#{entity_id} (#{entity_short}) is missing reference to #{ttl_entity[:uri]}"
          end
        end

        puts "\nFound #{missing_refs.size} #{entity_type} missing SI references"

        # Update references if requested
        return unless options[:update] && !missing_refs.empty?

        # If output is not specified and --update is set, update the original file
        output_file = if options[:output]
                        options[:output]
                      else
                        yaml_file # Use the original file path
                      end

        # Load and parse the YAML file correctly
        yaml_content = File.read(yaml_file)
        output_data = YAML.safe_load(yaml_content)

        # Process missing references
        missing_refs.each do |ref|
          entity_id = ref[:entity_id]

          # Find the entity in the array under the entity_type key
          entity_index = output_data[entity_type].find_index do |e|
            # Find entity with matching identifier
            e["identifiers"] && e["identifiers"].any? { |id| id["id"] == entity_id }
          end

          next unless entity_index

          # Get the entity
          entity = output_data[entity_type][entity_index]

          # Initialize references array if it doesn't exist
          entity["references"] ||= []

          # Check if reference already exists
          next if entity["references"].any? do |r|
            r["uri"] == ref[:si_uri] && r["authority"] == "si-digital-framework"
          end

          # Add new reference
          entity["references"] << {
            "uri" => ref[:si_uri],
            "type" => "normative",
            "authority" => "si-digital-framework"
          }
        end

        FileUtils.mkdir_p(File.dirname(output_file))
        File.write(output_file, output_data.to_yaml)
        puts "Updated references written to #{output_file}"
      end

      private

      def extract_entities(entity_type, graph)
        # Define prefixes used in the TTL files
        skos = RDF::Vocabulary.new("http://www.w3.org/2004/02/skos/core#")
        si = RDF::Vocabulary.new("http://si-digital-framework.org/SI#")

        namespace = case entity_type
                    when "units"
                      RDF::Vocabulary.new("http://si-digital-framework.org/SI/units/")
                    when "quantities"
                      RDF::Vocabulary.new("http://si-digital-framework.org/quantities/")
                    when "prefixes"
                      RDF::Vocabulary.new("http://si-digital-framework.org/SI/prefixes/")
                    else
                      return []
                    end

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

          # Get symbol if available for units and prefixes
          symbol = nil
          if %w[units prefixes].include?(entity_type)
            symbol_solution = RDF::Query.new(
              { RDF::URI(entity_uri) => { si.hasSymbol => :symbol } }
            ).execute(graph).first
            symbol = symbol_solution&.symbol&.to_s
          end

          entity_name = entity_uri.split("/").last
          label = label_solution&.label&.to_s

          entities << {
            uri: entity_uri,
            name: entity_name,
            label: label,
            symbol: symbol
          }
        end

        entities
      end

      def find_matching_entities(entity_type, entity_short, ttl_entities)
        return [] unless entity_short

        # Use the new search_text method to find matching entities
        matching_entities = []

        # First search for the entity_short
        matching_entities += ttl_entities.select do |ttl_entity|
          entity_short.downcase == ttl_entity[:name]&.downcase ||
            entity_short.downcase == ttl_entity[:label]&.downcase
        end

        # For units and prefixes, also search by symbol
        if %w[units prefixes].include?(entity_type)
          symbol_matches = ttl_entities.select do |ttl_entity|
            ttl_entity[:symbol] && entity_short.downcase == ttl_entity[:symbol].downcase
          end
          matching_entities += symbol_matches
        end

        matching_entities.uniq
      end
    end
  end
end
