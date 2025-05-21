# frozen_string_literal: true

require_relative "base"
require "yaml"

module Unitsdb
  module Commands
    class Normalize < Base
      def run(input = nil, output = nil)
        unless @options[:all] || (input && output)
          puts "Error: INPUT and OUTPUT are required when not using --all"
          exit(1)
        end

        if @options[:all]
          Unitsdb::Utils::DEFAULT_YAML_FILES.each do |file|
            path = File.join(@options[:database], file)
            next unless File.exist?(path)

            normalize_file(path, path)
            puts "Normalized #{path}"
          end
          puts "All YAML files normalized successfully!"
        end

        return unless input && output

        normalize_file(input, output)
        puts "Normalized YAML written to #{output}"
      end

      private

      def normalize_file(input, output)
        # Load the original YAML to work with
        yaml = YAML.safe_load(File.read(input))

        # For schema 2.0.0, we need to handle the schema_version and the main collection key
        if yaml.key?("schema_version") && yaml["schema_version"] == "2.0.0"
          # Get the collection key (units, scales, etc.)
          collection_key = (yaml.keys - ["schema_version"]).first

          # Sort the collection items if requested
          if @options[:sort] && @options[:sort] != "none" && collection_key
            # Sort the collection items based on the sort option
            case @options[:sort]
            when "nist", "unitsml"
              # Sort by ID (nist or unitsml)
              id_type = @options[:sort]
              yaml[collection_key] = sort_by_id_type(yaml[collection_key], id_type)
            else # default to "short"
              # Use the existing sort_yaml_keys method for default sorting
              yaml[collection_key] = Unitsdb::Utils.sort_yaml_keys(yaml[collection_key])
            end
          end
        elsif @options[:sort] && @options[:sort] != "none"
          # For any other format, just sort all keys
          yaml = Unitsdb::Utils.sort_yaml_keys(yaml)
        end

        # Write the normalized output
        File.write(output, yaml.to_yaml)
      end

      # Sort collection items by a specific ID type (nist or unitsml)
      def sort_by_id_type(collection, id_type)
        return collection unless collection.is_a?(Array)

        collection.sort_by do |item|
          # Find the identifier of the specified type
          identifier = if item.key?("identifiers") && item["identifiers"].is_a?(Array)
                         item["identifiers"].find { |id| id["type"] == id_type }
                       end

          # Use the ID if found, otherwise use a placeholder to sort to the end
          identifier ? identifier["id"].to_s : "zzzzz"
        end.map { |item| Unitsdb::Utils.sort_yaml_keys(item) }
      end
    end
  end
end
