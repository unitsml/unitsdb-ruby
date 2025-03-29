# frozen_string_literal: true

require_relative "identifier"
require_relative "unit_reference"
require_relative "dimension_reference"
require_relative "external_reference"
require_relative "localized_string"

module Unitsdb
  class Quantity < Lutaml::Model::Serializable
    # model Config.model_for(:quantity)

    attribute :identifiers, Identifier, collection: true
    attribute :quantity_type, :string
    attribute :names, LocalizedString, collection: true
    attribute :short, :string
    attribute :unit_references, UnitReference, collection: true
    attribute :dimension_reference, DimensionReference
    attribute :references, ExternalReference, collection: true
  end
end
