# frozen_string_literal: true

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

  Config.register_model(Prefix, id: :prefix)
end
