# frozen_string_literal: true

require_relative "base"
require "yaml"
require "zip"
require "fileutils"

module Unitsdb
  module Commands
    class Release < Base
      def run
        # Get release version (required parameter)
        release_version = @options[:version]

        # Verify version is in semantic format (x.y.z)
        unless release_version =~ /^\d+\.\d+\.\d+$/
          puts "Error: Version must be in semantic format (x.y.z)"
          exit(1)
        end

        # Create output directory if it doesn't exist
        output_dir = @options[:output_dir] || "."
        FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

        # Load the database from the specified directory
        begin
          database = Unitsdb::Database.from_db(@options[:database])
        rescue Unitsdb::Errors::DatabaseError => e
          puts "Error: #{e.message}"
          exit(1)
        end

        # Set the version field on the database
        database.version = release_version

        # Generate outputs based on format option
        format = @options[:format] || "all"

        case format.downcase
        when "yaml", "all"
          create_unified_yaml(database, release_version, output_dir)
        end

        case format.downcase
        when "zip", "all"
          create_zip_archive(database, release_version, output_dir)
        end

        puts "Release files created successfully in #{output_dir}"
      end

      private

      def create_unified_yaml(database, release_version, output_dir)
        # Write the unified YAML to a file
        output_file = File.join(output_dir, "unitsdb-#{release_version}.yaml")
        File.write(output_file, database.to_yaml)
        puts "Created unified YAML file: #{output_file}"
      end

      def create_zip_archive(database, release_version, output_dir)
        # Create a ZIP archive containing all YAML files
        output_file = File.join(output_dir, "unitsdb-#{release_version}.zip")
        temp_dir = File.join(output_dir, "temp_zip_files")

        begin
          # Create a temporary directory for version-added files
          FileUtils.mkdir_p(temp_dir)

          # Create individual YAML files with version field
          create_individual_yaml_files(database, release_version, temp_dir)

          # Create the ZIP file with versioned files
          Zip::File.open(output_file, Zip::File::CREATE) do |zipfile|
            Dir.glob(File.join(temp_dir, "*.yaml")).each do |file|
              # Get the filename without the path
              filename = File.basename(file)
              # Add the file to the ZIP archive
              zipfile.add(filename, file)
            end
          end

          puts "Created ZIP archive: #{output_file}"
        ensure
          # Clean up temporary directory
          FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
        end
      end

      def create_individual_yaml_files(database, release_version, temp_dir)
        # Create units.yaml
        units = Unitsdb::Units.new(
          schema_version: database.schema_version,
          version: release_version,
          units: database.units
        )
        File.write(File.join(temp_dir, "units.yaml"), units.to_yaml)

        # Create quantities.yaml
        quantities = Unitsdb::Quantities.new(
          schema_version: database.schema_version,
          version: release_version,
          quantities: database.quantities
        )
        File.write(File.join(temp_dir, "quantities.yaml"), quantities.to_yaml)

        # Create dimensions.yaml
        dimensions = Unitsdb::Dimensions.new(
          schema_version: database.schema_version,
          version: release_version,
          dimensions: database.dimensions
        )
        File.write(File.join(temp_dir, "dimensions.yaml"), dimensions.to_yaml)

        # Create prefixes.yaml
        prefixes = Unitsdb::Prefixes.new(
          schema_version: database.schema_version,
          version: release_version,
          prefixes: database.prefixes
        )
        File.write(File.join(temp_dir, "prefixes.yaml"), prefixes.to_yaml)

        # Create unit_systems.yaml
        unit_systems = Unitsdb::UnitSystems.new(
          schema_version: database.schema_version,
          version: release_version,
          unit_systems: database.unit_systems
        )
        File.write(File.join(temp_dir, "unit_systems.yaml"), unit_systems.to_yaml)
      end
    end
  end
end
