# frozen_string_literal: true

require_relative "unit"
require_relative "prefix"
require_relative "quantity"
require_relative "dimension"
require_relative "unit_system"

module Unitsdb
  class Database < Lutaml::Model::Serializable
    # model Config.model_for(:units)

    attribute :units, Unit, collection: true
    attribute :prefixes, Prefix, collection: true
    attribute :quantities, Quantity, collection: true
    attribute :dimensions, Dimension, collection: true
    attribute :unit_systems, UnitSystem, collection: true

    def self.from_db(dir_path)
      prefixes_hash = YAML.load(IO.read(File.join(dir_path, "prefixes.yaml")))
      dimensions_hash = YAML.load(IO.read(File.join(dir_path, "dimensions.yaml")))
      units_hash = YAML.load(IO.read(File.join(dir_path, "units.yaml")))
      quantities_hash = YAML.load(IO.read(File.join(dir_path, "quantities.yaml")))
      unit_systems_hash = YAML.load(IO.read(File.join(dir_path, "unit_systems.yaml")))

      combined_yaml = {
        prefixes: prefixes_yaml,
        dimensions: dimensions_yaml,
        units: units_yaml,
        quantities: quantities_yaml,
        unit_systems: unit_systems_yaml
      }.to_yaml

      from_yaml(combined_yaml)
    end
  end
end
