# frozen_string_literal: true

require_relative "unit_systems/unit_system"

module Unitsdb
  class UnitSystems
    include Lutaml::Model::Serialize
    model Config.model_for(:unit_systems)

    attribute :unit_systems, UnitSystem, collection: true

    key_value do
      map to: :unit_systems, root_mappings: {
        id: :key
      }
    end
  end
end
