# frozen_string_literal: true

require_relative "../symbol_presentations"

# - id: "dim_L"
#   ascii: "L"
#   html: "&#x1D5AB;"
#   mathml: "<mi mathvariant='sans-serif'>L</mi>"
#   latex: \ensuremath{\mathsf{L}}
#   unicode: "𝖫"

module Unitsdb
  class Dimensions
    class Symbol < SymbolPresentations
      model Config.model_for(:dimension_symbol)

      attribute :id, :string
      attribute :mathml, :string

      key_value do
        map :id, to: :id
        map :mathml, to: :mathml
      end
    end
  end
end
