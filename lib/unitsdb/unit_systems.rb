# frozen_string_literal: true

module Unitsdb
  class UnitSystems < Lutaml::Model::Serializable
    # model Config.model_for(:unit_systems)

    attribute :schema_version, :string
    attribute :version, :string
    attribute :unit_systems, UnitSystem, collection: true
  end

  Config.register_model(UnitSystems, id: :unit_systems)
end
