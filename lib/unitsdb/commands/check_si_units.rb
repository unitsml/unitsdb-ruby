# frozen_string_literal: true

require "rdf"
require "rdf/turtle"
require "yaml"
require_relative "base"
require_relative "../utils"
require_relative "../database"
require_relative "../external_reference"
require_relative "../errors"

module Unitsdb
  module Commands
    class CheckSiUnits < Base
      desc "check", "Check units in SI digital framework and add missing references"
      option :output, type: :string, aliases: "-o",
                      desc: "Output file path for updated YAML file"
      option :ttl_dir, type: :string, required: true, aliases: "-t",
                       desc: "Path to the directory containing SI digital framework TTL files"

      def check(options = {})
        database_path = options[:database]
        ttl_dir = options[:ttl_dir]
        output_file = options[:output] || "spec/fixtures/unitsdb.units.yaml"

        puts "Using database directory: #{database_path}"
        puts "Using TTL directory: #{ttl_dir}"

        # Verify TTL directory exists
        raise Unitsdb::DatabaseNotFoundError, "TTL directory not found: #{ttl_dir}" unless Dir.exist?(ttl_dir)

        # Load database
        database = load_database(database_path)
        db_units = database.units
        puts "Found #{db_units.size} units in database"

        # Parse RDF
        ttl_path = File.join(ttl_dir, "units.ttl")
        raise Unitsdb::DatabaseFileNotFoundError, "TTL file not found: #{ttl_path}" unless File.exist?(ttl_path)

        puts "Parsing TTL file: #{ttl_path}"
        ttl_units = parse_ttl(ttl_path)
        puts "Found #{ttl_units.size} units in SI digital framework"

        # Match units and check references
        matches, missing_refs = match_units(ttl_units, db_units)

        # Print statistics
        puts "\n=== Summary ==="
        puts "Units with SI references: #{matches.size}"
        puts "Units missing SI references: #{missing_refs.size}"

        if missing_refs.empty?
          puts "\nNo missing references found. All units have SI references."
          return
        end

        puts "\n=== Units missing SI references ==="
        missing_refs.each do |match|
          puts "✗ #{match[:db_unit].short || match[:db_unit].id} -> #{match[:ttl_unit][:uri]}"
        end

        # Update YAML and write to file
        update_yaml(database_path, missing_refs, output_file)
        puts "\nUpdated YAML written to #{output_file}"
      end

      private

      def parse_ttl(file_path)
        graph = RDF::Graph.new
        graph.from_file(file_path, format: :ttl)

        # Define prefixes used in the TTL file
        skos = RDF::Vocabulary.new("http://www.w3.org/2004/02/skos/core#")
        si = RDF::Vocabulary.new("http://si-digital-framework.org/SI#")
        units_ns = RDF::Vocabulary.new("http://si-digital-framework.org/SI/units/")

        result = []

        # Extract units from the graph
        RDF::Query.new({ unit: { skos.prefLabel => :label } }).execute(graph).each do |solution|
          unit_uri = solution.unit.to_s

          # Only process units in the correct namespace
          next unless unit_uri.start_with?(units_ns.to_s)

          # Get label
          label = solution.label.to_s if solution.label

          # Get symbol
          symbol_query = RDF::Query.new({ RDF::URI(unit_uri) => { si.hasSymbol => :symbol } })
          symbol_solution = symbol_query.execute(graph).first
          symbol = symbol_solution&.symbol&.to_s

          # Extract unit name from URI
          unit_name = unit_uri.split("/").last

          result << {
            uri: unit_uri,
            name: unit_name,
            label: label,
            symbol: symbol
          }
        end

        result
      end

      def match_units(ttl_units, db_units)
        matches = []
        missing_refs = []

        ttl_units.each do |ttl_unit|
          # Try to find a match in the database by name, label, or symbol
          matched_db_units = []

          # Match by name
          db_units.each do |db_unit|
            # Check if unit names match
            next unless match_unit_names?(db_unit, ttl_unit)

            # Check if the unit already has this reference
            if unit_has_reference?(db_unit, ttl_unit[:uri])
              matches << { db_unit: db_unit, ttl_unit: ttl_unit }
            else
              missing_refs << { db_unit: db_unit, ttl_unit: ttl_unit }
            end
            matched_db_units << db_unit
          end
        end

        [matches, missing_refs]
      end

      def match_unit_names?(db_unit, ttl_unit)
        # Match by short name (case insensitive)
        return true if db_unit.short && db_unit.short.downcase == ttl_unit[:name].downcase

        # Match by ID
        return true if db_unit.identifiers && db_unit.identifiers.any? { |id| id.id.downcase == ttl_unit[:name].downcase }

        # Match by label if available
        if ttl_unit[:label] && db_unit.respond_to?(:names) && db_unit.names && db_unit.names.any? do |name|
          name.downcase == ttl_unit[:label].downcase
        end
          return true
        end

        # Match by symbol if available
        if ttl_unit[:symbol] && db_unit.respond_to?(:symbols) && db_unit.symbols && db_unit.symbols.any? do |symbol|
          symbol.respond_to?(:ascii) && symbol.ascii && symbol.ascii.downcase == ttl_unit[:symbol].downcase
        end
          return true
        end

        false
      end

      def unit_has_reference?(unit, uri)
        unit.references && unit.references.any? do |ref|
          ref.uri == uri && ref.authority == "si-digital-framework"
        end
      end

      def update_yaml(database_path, missing_refs, output_file)
        # Load the original YAML file
        yaml_file = File.join(database_path, "units.yaml")
        yaml_content = YAML.safe_load(File.read(yaml_file))

        # Group by unit ID to avoid duplicates
        missing_refs_by_id = {}

        missing_refs.each do |match|
          db_unit = match[:db_unit]
          ttl_unit = match[:ttl_unit]

          # Find a suitable ID
          unit_id = find_unit_id(db_unit)

          missing_refs_by_id[unit_id] ||= []
          missing_refs_by_id[unit_id] << {
            uri: ttl_unit[:uri],
            type: "normative",
            authority: "si-digital-framework"
          }
        end

        # Update the YAML content
        yaml_content["units"].each do |unit_yaml|
          # Find unit by ID or short
          unit_id = unit_yaml["id"] || unit_yaml["identifiers"]&.first&.dig("id")

          next unless unit_id && missing_refs_by_id.key?(unit_id)

          # Add references
          unit_yaml["references"] ||= []

          missing_refs_by_id[unit_id].each do |ref|
            # Check if this reference already exists
            next if unit_yaml["references"].any? do |existing_ref|
              existing_ref["uri"] == ref[:uri] &&
              existing_ref["authority"] == ref[:authority]
            end

            # Add the reference
            unit_yaml["references"] << {
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

      def find_unit_id(unit)
        return unit.id if unit.respond_to?(:id) && unit.id
        return unit.identifiers.first.id if unit.identifiers&.first

        unit.short
      end
    end
  end
end
