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
        yaml = load_yaml(input)

        # Sort keys if requested
        yaml = Unitsdb::Utils.sort_yaml_keys(yaml) if @options[:sort]

        # Write the normalized output
        File.write(output, yaml.to_yaml)
      end
    end
  end
end
