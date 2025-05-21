# frozen_string_literal: true

require "yaml"
require "zip"
require "fileutils"

module Unitsdb
  module Commands
    class Release < ::Unitsdb::Commands::Base
      def run
        # Load the database
        db = load_database(@options[:database])
        db.version = @options[:version]

        # Create output directory if it doesn't exist
        FileUtils.mkdir_p(@options[:output_dir])

        # Generate release files based on format option
        format = (@options[:format] || "all").downcase
        case format
        when "yaml"
          create_unified_yaml(db)
        when "zip"
          create_zip_archive(db)
        when "all"
          create_unified_yaml(db)
          create_zip_archive(db)
        else
          puts "Invalid format option: #{@options[:format]}"
          puts "Valid options are: 'yaml', 'zip', or 'all'"
          exit(1)
        end

        puts "Release files created successfully in #{@options[:output_dir]}"
      rescue Unitsdb::Errors::DatabaseError => e
        puts "Error: #{e.message}"
        exit(1)
      end

      private

      def create_unified_yaml(db)
        # Create a unified YAML file with all database components
        output_path = File.join(@options[:output_dir], "unitsdb-#{@options[:version]}.yaml")
        File.write(output_path, db.to_yaml)
        puts "Created unified YAML file: #{output_path}"
      end

      def create_zip_archive(db)
        # Create a ZIP archive with individual YAML files
        output_path = File.join(@options[:output_dir], "unitsdb-#{@options[:version]}.zip")

        Zip::File.open(output_path, Zip::File::CREATE) do |zipfile|
          {
            dimensions: Unitsdb::Dimensions,
            unit_systems: Unitsdb::UnitSystems,
            units: Unitsdb::Units,
            prefixes: Unitsdb::Prefixes,
            quantities: Unitsdb::Quantities
          }.each_pair do |access_method, collection_klass|
            db.send(access_method).tap do |data|
              collection = collection_klass.new(access_method => data)
              collection.version = @options[:version]
              zipfile.get_output_stream("#{access_method}.yaml") { |f| f.write(collection.to_yaml) }
            end
          end
        end

        puts "Created ZIP archive: #{output_path}"
      end
    end
  end
end
