# frozen_string_literal: true

module Unitsdb
  class UnitSystems
    class UnitSystem < Lutaml::Model::Serializable
      model Config.model_for(:unit_system)

      attribute :id, :string
      attribute :name, :string
      attribute :acceptable, :boolean

      key_value do
        map :id, to: :id
        map :name, to: :name
        map :acceptable, to: :acceptable
      end
    end
  end
end
