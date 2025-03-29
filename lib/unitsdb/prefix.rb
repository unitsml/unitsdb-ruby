# frozen_string_literal: true

require_relative "identifier"
require_relative "symbol_presentations"
require_relative "external_reference"
require_relative "localized_string"
# ---
# NISTp10_30:
#   name: quetta
#   symbol:
#     ascii: Q
#     html: Q
#     latex: Q
#     unicode: Q
#   base: 10
#   power: 30

module Unitsdb
  class Prefix < Lutaml::Model::Serializable
    # model Config.model_for(:prefix)

    attribute :identifiers, Identifier, collection: true
    attribute :names, LocalizedString, collection: true
    attribute :short, :string
    attribute :symbols, SymbolPresentations, collection: true
    attribute :base, :integer
    attribute :power, :integer
    attribute :references, ExternalReference, collection: true
  end
end
