# frozen_string_literal: true

require_relative "base"
require "yaml"

module Unitsdb
  module Commands
    class Normalize < Base
      desc "yaml [INPUT] [OUTPUT]", "Normalize a YAML file or all YAML files with --all"
      method_option :sort, type: :boolean, default: true, desc: "Sort keys alphabetically"

      def yaml(input = nil, output = nil, opts = nil)
        options_to_use = opts || options

        unless options_to_use[:all] || (input && output)
          puts "Error: INPUT and OUTPUT are required when not using --all"
          exit(1)
        end

        if options_to_use[:all]
          Unitsdb::Utils::DEFAULT_YAML_FILES.each do |file|
            path = File.join(options_to_use[:database], file)
            next unless File.exist?(path)

            normalize_file(path, path, options_to_use)
            puts "Normalized #{path}"
          end
          puts "All YAML files normalized successfully!"
        end

        return unless input && output

        normalize_file(input, output, options_to_use)
        puts "Normalized YAML written to #{output}"
      end

      private

      def normalize_file(input, output, opts)
        # Load the original YAML to work with
        yaml = load_yaml(input)

        # Sort keys if requested
        yaml = Unitsdb::Utils.sort_yaml_keys(yaml) if opts[:sort]

        # Write the normalized output
        File.write(output, yaml.to_yaml)
      end
    end
  end
end
