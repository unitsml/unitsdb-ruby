# frozen_string_literal: true

require "yaml"

module Unitsdb
  class Database
    # Filesystem and YAML-schema layer of Database. Reads the
    # collection YAML files from a directory, validates their schema
    # versions agree, and returns a combined hash ready for
    # Lutaml::Model deserialization. Knows nothing about contexts or
    # registers — that's `Database.from_db`'s job.
    class Loader
      REQUIRED_DATABASE_FILES = {
        "prefixes" => "prefixes.yaml",
        "dimensions" => "dimensions.yaml",
        "units" => "units.yaml",
        "quantities" => "quantities.yaml",
        "unit_systems" => "unit_systems.yaml",
      }.freeze

      # Present in 2.0-era data onward; absent in older bundled data
      # directories, which must keep loading. When present, the file
      # participates in all validation like a required file.
      OPTIONAL_DATABASE_FILES = {
        "currencies" => "currencies.yaml",
      }.freeze

      DATABASE_FILES = REQUIRED_DATABASE_FILES.merge(OPTIONAL_DATABASE_FILES).freeze

      SUPPORTED_SCHEMA_VERSION = "2.0.0"

      def self.load(dir_path)
        new(dir_path).load
      end

      def initialize(dir_path)
        @dir_path = File.expand_path(dir_path.to_s)
      end

      # Read every YAML file under @dir_path, validate schema versions,
      # and return a combined hash keyed by collection name.
      def load
        verify_directory!
        documents = read_documents
        schema_version = validate_schema_versions!(documents)
        build_database_hash(documents, schema_version)
      end

      private

      def verify_directory!
        unless Dir.exist?(@dir_path)
          raise Errors::DatabaseNotFoundError,
                "Database directory not found: #{@dir_path}"
        end

        missing = REQUIRED_DATABASE_FILES.values.reject do |filename|
          File.exist?(File.join(@dir_path, filename))
        end
        return if missing.empty?

        raise Errors::DatabaseFileNotFoundError,
              "Missing required database files: #{missing.join(', ')}"
      end

      def read_documents
        if ENV["UNITSDB_DEBUG"]
          puts "[UnitsDB] Loading YAML files from directory: #{@dir_path}"
        end
        DATABASE_FILES.filter_map do |collection_key, filename|
          path = File.join(@dir_path, filename)
          next unless File.exist?(path)

          puts "  - #{path}" if ENV["UNITSDB_DEBUG"]
          [collection_key, read_yaml(path, filename)]
        end.to_h
      end

      def read_yaml(path, filename)
        document = YAML.safe_load_file(path)
        unless document.is_a?(Hash)
          raise Errors::DatabaseFileInvalidError,
                "Invalid YAML structure in #{filename}: expected a mapping"
        end

        document
      rescue Errno::ENOENT => e
        raise Errors::DatabaseFileNotFoundError,
              "Failed to read database file: #{e.message}"
      rescue Psych::SyntaxError => e
        raise Errors::DatabaseFileInvalidError,
              "Invalid YAML in database file: #{e.message}"
      rescue Errors::DatabaseError
        raise
      rescue StandardError => e
        raise Errors::DatabaseLoadError,
              "Error loading database file #{filename}: #{e.message}"
      end

      def validate_schema_versions!(documents)
        versions = documents.each_with_object({}) do |(collection_key, document), result|
          filename = DATABASE_FILES.fetch(collection_key)
          result[filename] = document.fetch("schema_version")
        rescue KeyError
          raise Errors::DatabaseFileInvalidError,
                "Missing schema_version in #{filename}"
        end

        unless versions.values.uniq.size == 1
          raise Errors::VersionMismatchError,
                "Version mismatch in database files: #{versions.inspect}"
        end

        version = versions.values.first
        return version if version == SUPPORTED_SCHEMA_VERSION

        raise Errors::UnsupportedVersionError,
              "Unsupported database version: #{version}. " \
              "Only version #{SUPPORTED_SCHEMA_VERSION} is supported."
      end

      def build_database_hash(documents, schema_version)
        hash = {
          "schema_version" => schema_version,
        }.merge(
          documents.to_h do |collection_key, document|
            [collection_key, fetch_collection!(document, collection_key)]
          end,
        )
        # Absent optional collections normalize to empty arrays so
        # Database accessors never return nil for legacy data dirs.
        OPTIONAL_DATABASE_FILES.each_key { |key| hash[key] ||= [] }
        hash
      end

      def fetch_collection!(document, collection_key)
        document.fetch(collection_key)
      rescue KeyError
        raise Errors::DatabaseFileInvalidError,
              "Missing #{collection_key} collection in #{DATABASE_FILES.fetch(collection_key)}"
      end
    end

    # Backwards-compat aliases — external callers (and the spec) read
    # these constants off Database directly.
    DATABASE_FILES = Loader::DATABASE_FILES
    SUPPORTED_SCHEMA_VERSION = Loader::SUPPORTED_SCHEMA_VERSION
  end
end
