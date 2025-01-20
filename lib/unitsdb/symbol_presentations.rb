# frozen_string_literal: true

module Unitsdb
  class SymbolPresentations < Lutaml::Model::Serializable
    model Config.model_for(:symbol_presentations)

    attribute :ascii, :string
    attribute :html, :string
    attribute :latex, :string
    attribute :unicode, :string

    key_value do
      map :ascii, to: :ascii
      map :html, to: :html
      map :latex, to: :latex
      map :unicode, to: :unicode
    end
  end
end
