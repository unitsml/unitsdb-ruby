# frozen_string_literal: true

require_relative "dimension_quantity"
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

# NISTd9:
# -dimensionless: true
# -plane_angle:
# -  dim_symbols:
# -  - ascii: phi
# -    html: "&#x1D785;"
# -    id: dim_phi
# -    latex: "\\ensuremath{\\mathsf{\\phi}}"
# -    mathml: "<mi mathvariant='sans-serif'>&#x3c6;</mi>"
# -    unicode: "\U0001D785"
# -  powerNumerator: 1
# -  symbol: phi

module Unitsdb
  class Dimension < Lutaml::Model::Serializable
    attribute :id, :string
    attribute :dimensionless, :boolean
    attribute :length, DimensionQuantity
    attribute :mass, DimensionQuantity
    attribute :time, DimensionQuantity
    attribute :electric_current, DimensionQuantity
    attribute :thermodynamic_temperature, DimensionQuantity
    attribute :amount_of_substance, DimensionQuantity
    attribute :luminous_intensity, DimensionQuantity
    attribute :plane_angle, DimensionQuantity

    key_value do
      map :id, to: :id
      map :dimensionless, to: :dimensionless
      map :length, to: :length
      map :mass, to: :mass
      map :time, to: :time
      map :electric_current, to: :electric_current
      map :thermodynamic_temperature, to: :thermodynamic_temperature
      map :amount_of_substance, to: :amount_of_substance
      map :luminous_intensity, to: :luminous_intensity
      map :plane_angle, to: :plane_angle
    end
  end
end
