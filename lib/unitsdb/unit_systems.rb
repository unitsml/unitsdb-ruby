# frozen_string_literal: true

require_relative "unit_system"

module Unitsdb
  class UnitSystems < Lutaml::Model::Serializable
    attribute :unit_system, UnitSystem, collection: true

    # TODO: How do I parse this?
    # ---
    # - id: SI_base
    #   name: SI
    #   acceptable: true
    # - id: SI_derived_special
    #   name: SI
    #   acceptable: true
    # - id: SI_derived_non-special

    key_value do
      map to: :unit_system, root_mappings: {
        id: :key
      }
    end
  end
end
