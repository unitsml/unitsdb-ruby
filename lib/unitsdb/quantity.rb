# frozen_string_literal: true

module Unitsdb
  class Quantity < Lutaml::Model::Serializable
    attribute :identifiers, Identifier, collection: true
    attribute :quantity_type, :string
    attribute :names, LocalizedString, collection: true
    attribute :short, :string
    attribute :unit_references, UnitReference, collection: true
    attribute :dimension_reference, DimensionReference
    attribute :references, ExternalReference, collection: true
  end

  Config.register_model(Quantity, id: :quantity)
end
