# frozen_string_literal: true

module Unitsdb
  class Currency < Lutaml::Model::Serializable
    attribute :identifiers, Identifier, collection: true
    attribute :names, LocalizedString, collection: true
    attribute :symbols, SymbolPresentations, collection: true
    attribute :minor_unit_exponent, :integer
    attribute :status, :string
    attribute :unit_system_reference, UnitSystemReference, collection: true
    attribute :quantity_references, QuantityReference, collection: true
    attribute :notes, :string
  end

  Config.register_model(Currency, id: :currency)
end
