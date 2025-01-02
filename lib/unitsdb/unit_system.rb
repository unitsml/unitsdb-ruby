# frozen_string_literal: true

module Unitsdb
  class UnitSystem < Lutaml::Model::Serializable
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
