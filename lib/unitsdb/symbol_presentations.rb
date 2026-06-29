# frozen_string_literal: true

module Unitsdb
  class SymbolPresentations < Lutaml::Model::Serializable
    attribute :id, :string
    attribute :ascii, :string
    attribute :html, :string
    attribute :latex, :string
    attribute :mathml, :string
    attribute :unicode, :string
  end

  Config.register_model(SymbolPresentations, id: :symbol_presentations)
end
