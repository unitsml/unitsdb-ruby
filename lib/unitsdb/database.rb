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

    def self.from_db(dir_path)
      prefixes_hash = YAML.safe_load(IO.read(File.join(dir_path, "prefixes.yaml")))
      dimensions_hash = YAML.safe_load(IO.read(File.join(dir_path, "dimensions.yaml")))
      units_hash = YAML.safe_load(IO.read(File.join(dir_path, "units.yaml")))
      quantities_hash = YAML.safe_load(IO.read(File.join(dir_path, "quantities.yaml")))
      unit_systems_hash = YAML.safe_load(IO.read(File.join(dir_path, "unit_systems.yaml")))

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
