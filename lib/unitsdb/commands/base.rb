# frozen_string_literal: true

require "thor"
require "yaml"
require_relative "../utils"
require_relative "../database"

module Unitsdb
  module Commands
    class Base
      def initialize(options = {})
        @options = options
      end

      protected

      def yaml_files(input = nil, opts = nil)
        options_to_use = opts || @options

        if options_to_use[:all]
          Unitsdb::Utils::DEFAULT_YAML_FILES.map { |f| File.join(options_to_use[:database], f) }
        elsif input
          [input]
        else
          puts "Error: INPUT file is required when not using --all"
          exit(1)
        end
      end

      def load_database(database_path = nil)
        path = database_path || @options[:database]

        raise Unitsdb::Errors::DatabaseError, "Database path must be specified using the --database option" if path.nil?

        Unitsdb::Database.from_db(path)
      rescue Unitsdb::Errors::DatabaseError => e
        puts "Error: #{e.message}"
        exit(1)
      end

      def load_yaml(file_path)
        return nil unless File.exist?(file_path)

        YAML.safe_load(File.read(file_path))
      end

      def file_type(file_path)
        File.basename(file_path, ".yaml")
      end
    end
  end
end
