# frozen_string_literal: true

module Unitsdb
  class SymbolPresentations < Lutaml::Model::Serializable
    # model Config.model_for(:symbol_presentations)

    attribute :id, :string
    attribute :ascii, :string
    attribute :html, :string
    attribute :latex, :string
    attribute :mathml, :string
    attribute :unicode, :string
  end
end
