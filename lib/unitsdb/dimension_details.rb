# frozen_string_literal: true

# power: 1
# symbol: M
# symbols:
# - ascii: M
#   html: "&#x1D5AC;"
#   id: dim_M
#   latex: "\\ensuremath{\\mathsf{M}}"
#   mathml: "<mi mathvariant='sans-serif'>M</mi>"
#   unicode: "\U0001D5AC"

require_relative "symbol_presentations"
module Unitsdb
  class DimensionDetails < Lutaml::Model::Serializable
    attribute :power, :integer
    attribute :symbol, :string
    attribute :symbols, SymbolPresentations, collection: true
  end
end
