# frozen_string_literal: true

require "rdf"
require "rdf/turtle"
require_relative "../utils"
require_relative "../database"
require_relative "../external_reference"

module Unitsdb
  module Commands
    class CheckSiReferences < Base
      desc "check", "Check entities in SI digital framework against entities in the database"
      option :entity_type, type: :string, aliases: "-e",
                           desc: "Entity type to check (units, quantities, or prefixes). If not specified, all types are checked"
      option :output, type: :string, aliases: "-o",
                      desc: "Output file path for updated YAML file(s)"
      option :update, type: :boolean, default: false,
                      desc: "Update references in output file(s)"

      # Entity types supported by this command
      ENTITY_TYPES = %w[units quantities prefixes].freeze

      def check
        merged_options = options
        # Use absolute path to make sure we're in the right directory
        dir_path = File.expand_path(merged_options[:dir] || ".")
        puts "Using database directory: #{dir_path}"

        # Make sure the database is loaded with full path to the directory
        @db = Unitsdb::Database.from_db(dir_path)

        # Path to references directory (should be in the root project directory)
        ttl_dir = File.join(File.expand_path(File.join(__dir__, "../../..")), "references")

        # Parse all TTL files once
        graph = parse_ttl_files(ttl_dir)

        # Process each entity type
        entity_type = merged_options[:entity_type]&.downcase

        if entity_type && ENTITY_TYPES.include?(entity_type)
          # Process only the specified entity type
          process_entity_type(entity_type, @db, graph, merged_options)
        else
          # Process all entity types
          ENTITY_TYPES.each do |type|
            process_entity_type(type, @db, graph, merged_options)
          end
        end
      end

      private

      def process_entity_type(entity_type, db, graph, options)
        puts "\n========== Processing #{entity_type.upcase} ==========\n"

        # Get entities from DB and TTL
        db_entities = db.send(entity_type)
        ttl_entities = extract_entities_from_ttl(entity_type, graph)

        puts "Found #{ttl_entities.size} #{entity_type} in SI digital framework"
        puts "Found #{db_entities.size} #{entity_type} in database"

        # Match entities
        matches, missing_matches, unmatched_ttl = match_entities(entity_type, ttl_entities, db_entities)

        # Print results
        puts "\n=== #{entity_type.capitalize} with matching SI references ==="
        if matches.empty?
          puts "None"
        else
          matches.each do |match|
            puts "✓ #{match[:entity_id]} (#{match[:entity_short]}) -> #{match[:si_uri]}"
          end
        end

        puts "\n=== #{entity_type.capitalize} without SI references ==="
        if missing_matches.empty?
          puts "None"
        else
          missing_matches.each do |match|
            puts "✗ #{match[:entity_id]} (#{match[:entity_short]}) -> #{match[:si_uri]} (missing reference)"
          end
        end

        puts "\n=== SI #{entity_type.capitalize} not mapped to our database ==="
        if unmatched_ttl.empty?
          puts "None"
        else
          unmatched_ttl.each do |entity|
            puts "? #{entity[:name]} (#{entity[:label]}) -> #{entity[:uri]}"
          end
        end

        puts "\n=== Summary for #{entity_type.capitalize} ==="
        puts "Total matches: #{matches.size + missing_matches.size}"
        puts "#{entity_type.capitalize} with SI references: #{matches.size}"
        puts "#{entity_type.capitalize} missing SI references: #{missing_matches.size}"
        puts "SI #{entity_type.capitalize} not matched in our database: #{unmatched_ttl.size}"

        # Update references if requested
        return unless options[:update] && !missing_matches.empty?

        output_file = options[:output] || "spec/fixtures/unitsdb/#{entity_type}_si_updated.yaml"
        update_references(entity_type, missing_matches, db_entities, output_file)
        puts "\nUpdated references written to #{output_file}"
      end

      private

      def parse_ttl_files(dir)
        puts "Parsing TTL files in #{dir}..."
        graph = RDF::Graph.new

        # Find all TTL files in the references directory
        ttl_files = Dir.glob(File.join(dir, "*.ttl"))
        ttl_files.each do |file|
          puts "  Reading #{File.basename(file)}"
          graph.from_file(file, format: :ttl)
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

      def match_entities(entity_type, ttl_entities, db_entities)
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
            entity_id = entity.identifiers&.first&.value

            # Check if this entity already has a reference to SI digital framework
            has_reference = entity.references&.any? do |ref|
              ref.uri == ttl_entity[:uri] && ref.authority == "si-digital-framework"
            end

            match_data = {
              entity_id: entity_id,
              entity_short: entity.short,
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
        matching_units = @db.search_text(ttl_unit[:name], type: "units")
        matching_units += @db.search_text(ttl_unit[:label], type: "units") if ttl_unit[:label]

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
        matching_quantities = @db.search_text(ttl_quantity[:name], type: "quantities")
        matching_quantities += @db.search_text(ttl_quantity[:label], type: "quantities") if ttl_quantity[:label]
        matching_quantities += @db.search_text(ttl_quantity[:alt_label], type: "quantities") if ttl_quantity[:alt_label]

        matching_quantities.uniq
      end

      def find_matching_prefixes(ttl_prefix, _prefixes)
        # Match by name or label
        matching_prefixes = @db.search_text(ttl_prefix[:name], type: "prefixes")
        matching_prefixes += @db.search_text(ttl_prefix[:label], type: "prefixes") if ttl_prefix[:label]

        # If no match by name, try by symbol
        if matching_prefixes.empty? && ttl_prefix[:symbol]
          matching_prefixes = _prefixes.select do |prefix|
            prefix.symbol&.ascii&.downcase == ttl_prefix[:symbol]&.downcase
          end
        end

        matching_prefixes.uniq
      end

      def update_references(entity_type, missing_matches, entities, output_file)
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
            e["identifiers"] && e["identifiers"].any? { |id| id["id"] == entity_id }
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
    end
  end
end
