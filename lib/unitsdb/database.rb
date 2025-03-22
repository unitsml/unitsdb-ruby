# frozen_string_literal: true

require_relative "unit"
require_relative "prefix"
require_relative "quantity"
require_relative "dimension"
require_relative "unit_system"

module Unitsdb
  class Database < Lutaml::Model::Serializable
    # model Config.model_for(:units)

    attribute :schema_version, :string
    attribute :units, Unit, collection: true
    attribute :prefixes, Prefix, collection: true
    attribute :quantities, Quantity, collection: true
    attribute :dimensions, Dimension, collection: true
    attribute :unit_systems, UnitSystem, collection: true

    # Find an entity by its identifier and type
    # @param id [String] the identifier value to search for
    # @param type [String, Symbol] the entity type (units, prefixes, quantities, etc.)
    # @return [Object, nil] the first entity with matching identifier or nil if not found
    def search(id:, type:)
      collection = send(type.to_s)
      collection.find { |entity| entity.identifiers&.any? { |identifier| identifier.value == id } }
    end

    # Search for entities containing the given text in identifiers, names, or short description
    # @param text [String] the text to search for
    # @param type [String, Symbol, nil] optional entity type to limit search scope
    # @return [Array] all entities matching the search criteria
    def search_text(text, type: nil)
      results = []

      # Define which collections to search based on type parameter
      collections = type ? [type.to_s] : %w[units prefixes quantities dimensions unit_systems]

      collections.each do |collection_name|
        next unless respond_to?(collection_name)

        collection = send(collection_name)
        collection.each do |entity|
          # Search in identifiers
          if entity.identifiers&.any? { |identifier| identifier.value.to_s.downcase.include?(text.downcase) }
            results << entity
            next
          end

          # Search in names (if the entity has names)
          if entity.respond_to?(:names) && entity.names &&
             entity.names.any? { |name| name.to_s.downcase.include?(text.downcase) }
            results << entity
            next
          end

          # Search in short description
          if entity.respond_to?(:short) && entity.short &&
             entity.short.to_s.downcase.include?(text.downcase)
            results << entity
            next
          end

          # Special case for prefix name (prefixes don't have names array)
          next unless collection_name == "prefixes" && entity.respond_to?(:name) &&
                      entity.name.to_s.downcase.include?(text.downcase)

          results << entity
          next
        end
      end

      results
    end

    def self.from_db(dir_path)
      # Ensure we have path properly joined with filenames
      prefixes_yaml = File.join(dir_path, "prefixes.yaml")
      dimensions_yaml = File.join(dir_path, "dimensions.yaml")
      units_yaml = File.join(dir_path, "units.yaml")
      quantities_yaml = File.join(dir_path, "quantities.yaml")
      unit_systems_yaml = File.join(dir_path, "unit_systems.yaml")

      # Debug paths
      if ENV["DEBUG"]
        puts "[UnitsDB] Loading YAML files from directory: #{dir_path}"
        puts "  - #{prefixes_yaml}"
        puts "  - #{dimensions_yaml}"
        puts "  - #{units_yaml}"
        puts "  - #{quantities_yaml}"
        puts "  - #{unit_systems_yaml}"
      end

      prefixes_hash = YAML.safe_load(File.read(prefixes_yaml))
      dimensions_hash = YAML.safe_load(File.read(dimensions_yaml))
      units_hash = YAML.safe_load(File.read(units_yaml))
      quantities_hash = YAML.safe_load(File.read(quantities_yaml))
      unit_systems_hash = YAML.safe_load(File.read(unit_systems_yaml))

      # Extract versions from each file
      prefixes_version = prefixes_hash["schema_version"]
      dimensions_version = dimensions_hash["schema_version"]
      units_version = units_hash["schema_version"]
      quantities_version = quantities_hash["schema_version"]
      unit_systems_version = unit_systems_hash["schema_version"]

      # Check if all versions match
      versions = [
        prefixes_version,
        dimensions_version,
        units_version,
        quantities_version,
        unit_systems_version
      ]

      unless versions.uniq.size == 1
        version_info = {
          "prefixes.yaml" => prefixes_version,
          "dimensions.yaml" => dimensions_version,
          "units.yaml" => units_version,
          "quantities.yaml" => quantities_version,
          "unit_systems.yaml" => unit_systems_version
        }
        # Define custom error class for version mismatches
        raise Unitsdb::VersionMismatchError, "Version mismatch in database files: #{version_info.inspect}"
      end

      combined_yaml = {
        "schema_version" => prefixes_version,
        "prefixes" => prefixes_hash["prefixes"],
        "dimensions" => dimensions_hash["dimensions"],
        "units" => units_hash["units"],
        "quantities" => quantities_hash["quantities"],
        "unit_systems" => unit_systems_hash["unit_systems"]
      }.to_yaml

      from_yaml(combined_yaml)
    end
  end
end
