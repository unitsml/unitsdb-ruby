# frozen_string_literal: true

require_relative "base"
require "yaml"
require "zip"
require "fileutils"

module Unitsdb
  module Commands
    class Release < Base
      def run
        # Verify all required files exist
        yaml_files = Unitsdb::Utils::DEFAULT_YAML_FILES.map { |f| File.join(@options[:database], f) }
        missing_files = yaml_files.reject { |f| File.exist?(f) }

        if missing_files.any?
          puts "Error: The following required files are missing:"
          missing_files.each { |f| puts "  - #{f}" }
          exit(1)
        end

        # Extract schema version from any file (they should all have the same version)
        first_yaml = load_yaml(yaml_files.first)
        schema_version = first_yaml["schema_version"]

        unless schema_version
          puts "Error: Could not determine schema version from #{yaml_files.first}"
          exit(1)
        end

        # Verify all files have the same schema version
        inconsistent_files = []
        yaml_files.each do |file|
          yaml = load_yaml(file)
          next unless yaml["schema_version"] != schema_version

          inconsistent_files << {
            file: file,
            version: yaml["schema_version"]
          }
        end

        if inconsistent_files.any?
          puts "Error: Inconsistent schema versions detected:"
          puts "  Expected version: #{schema_version}"
          inconsistent_files.each do |info|
            puts "  - #{info[:file]}: #{info[:version]}"
          end
          exit(1)
        end

        # Create output directory if it doesn't exist
        output_dir = @options[:output_dir] || "."
        FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

        # Generate outputs based on format option
        format = @options[:format] || "all"

        case format.downcase
        when "yaml", "all"
          create_unified_yaml(yaml_files, schema_version, output_dir)
        end

        case format.downcase
        when "zip", "all"
          create_zip_archive(yaml_files, schema_version, output_dir)
        end

        puts "Release files created successfully in #{output_dir}"
      end

      private

      def create_unified_yaml(yaml_files, schema_version, output_dir)
        # Create a unified YAML structure
        unified_yaml = { "schema_version" => schema_version }

        # Load each YAML file and add its collection to the unified structure
        yaml_files.each do |file|
          yaml = load_yaml(file)
          # Get the collection key (units, scales, etc.) - it's the key that's not schema_version
          collection_key = (yaml.keys - ["schema_version"]).first
          if collection_key
            # Add the collection to the unified structure
            unified_yaml[collection_key] = yaml[collection_key]
          end
        end

        # Write the unified YAML to a file
        output_file = File.join(output_dir, "unitsdb-#{schema_version}.yaml")
        File.write(output_file, unified_yaml.to_yaml)
        puts "Created unified YAML file: #{output_file}"
      end

      def create_zip_archive(yaml_files, schema_version, output_dir)
        # Create a ZIP archive containing all YAML files
        output_file = File.join(output_dir, "unitsdb-#{schema_version}.zip")

        Zip::File.open(output_file, Zip::File::CREATE) do |zipfile|
          yaml_files.each do |file|
            # Get the filename without the path
            filename = File.basename(file)
            # Add the file to the ZIP archive
            zipfile.add(filename, file)
          end
        end

        puts "Created ZIP archive: #{output_file}"
      end
    end
  end
end
