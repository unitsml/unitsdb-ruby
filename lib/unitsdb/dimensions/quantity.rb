# frozen_string_literal: true

require_relative "symbol"
# NISTd1:
#   length:
#     powerNumerator: 1
#     symbol: L
#     dim_symbols:
#     - id: "dim_L"
#       ascii: "L"
#       html: "&#x1D5AB;"
#       mathml: "<mi mathvariant='sans-serif'>L</mi>"
#       latex: \ensuremath{\mathsf{L}}
#       unicode: "𝖫"

module Unitsdb
  class Dimensions
    class Quantity < Lutaml::Model::Serializable
      model Config.model_for(:dimension_quantity)

      attribute :power_numerator, :integer
      attribute :symbol, :string
      attribute :dim_symbols, Symbol, collection: true

      key_value do
        map :powerNumerator, to: :power_numerator
        map :symbol, to: :symbol
        map :dim_symbols, to: :dim_symbols
      end
    end
  end
end
