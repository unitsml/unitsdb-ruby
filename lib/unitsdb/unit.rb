# frozen_string_literal: true

module Unitsdb
  class Unit < Lutaml::Model::Serializable
    attribute :identifiers, Identifier, collection: true
    attribute :short, :string
    attribute :root, :boolean
    attribute :prefixed, :boolean
    attribute :dimension_reference, DimensionReference
    attribute :unit_system_reference, UnitSystemReference, collection: true
    attribute :names, LocalizedString, collection: true
    attribute :symbols, SymbolPresentations, collection: true
    attribute :quantity_references, QuantityReference, collection: true
    attribute :si_derived_bases, SiDerivedBase, collection: true
    attribute :root_units, RootUnitReference, collection: true
    attribute :references, ExternalReference, collection: true
    attribute :scale_reference, ScaleReference
  end

  Config.register_model(Unit, id: :unit)
end
