# frozen_string_literal: true

require_relative "identifier"
require_relative "dimension_details"
require_relative "quantity"
require_relative "localized_string"
# NISTd1:
#   length:
#     power: 1
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
# -  power: 1
# -  symbol: phi

module Unitsdb
  class Dimension < Lutaml::Model::Serializable
    # model Config.model_for(:dimension)

    attribute :identifiers, Identifier, collection: true
    attribute :dimensionless, :boolean
    attribute :length, DimensionDetails
    attribute :mass, DimensionDetails
    attribute :time, DimensionDetails
    attribute :electric_current, DimensionDetails
    attribute :thermodynamic_temperature, DimensionDetails
    attribute :amount_of_substance, DimensionDetails
    attribute :luminous_intensity, DimensionDetails
    attribute :plane_angle, DimensionDetails
    attribute :short, :string
    attribute :names, LocalizedString, collection: true
  end
end
