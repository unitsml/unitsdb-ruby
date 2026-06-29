# frozen_string_literal: true

module Unitsdb
  class Prefix < Lutaml::Model::Serializable
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
