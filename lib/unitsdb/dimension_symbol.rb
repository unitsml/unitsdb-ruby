# frozen_string_literal: true

require_relative "symbol"

# - id: "dim_L"
#   ascii: "L"
#   html: "&#x1D5AB;"
#   mathml: "<mi mathvariant='sans-serif'>L</mi>"
#   latex: \ensuremath{\mathsf{L}}
#   unicode: "𝖫"

module Unitsdb
  class DimensionSymbol < Symbol
    attribute :id, :string
    attribute :mathml, :string

    key_value do
      map :id, to: :id
      map :mathml, to: :mathml
    end
  end
end
