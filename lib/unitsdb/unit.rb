# frozen_string_literal: true

require_relative "symbol_presentations"
require_relative "unit_system_reference"
require_relative "root_unit_reference"
require_relative "si_derived_base"
require_relative "quantity_reference"
require_relative "dimension_reference"
require_relative "external_reference"
require_relative "localized_string"
require_relative "scale_reference"

# "NISTu10":
#   dimension_url: "#NISTd9"
#   short: steradian
#   root: true
#   unit_system:
#     type: "SI_derived_special"
#     name: "SI"
#   names:
#     - "steradian"
#   unit_symbols:
#     - id: "sr"
#       ascii: "sr"
#       html: "sr"
#       mathml: "<mi mathvariant='normal'>sr</mi>"
#       latex: \ensuremath{\mathrm{sr}}
#       unicode: "sr"
#   root_units:
#     enumerated_root_units:
#       - unit: "steradian"
#         power_denominator: 1
#         power: 1
#   quantity_reference:
#     - name: "solid angle"
#       url: "#NISTq11"
#   si_derived_bases:
#     - id: NISTu1
#       prefix:
#       power: 1
#     - id: NISTu1
#       prefix:
#       power: -1

module Unitsdb
  class Unit < Lutaml::Model::Serializable
    # model Config.model_for(:unit)

    attribute :identifiers, Identifier, collection: true
    attribute :short, :string
    attribute :root, :boolean
    attribute :prefixed, :boolean
    attribute :dimension_reference, DimensionReference
    attribute :unit_system_reference, UnitSystemReference, collection: true
    attribute :names, LocalizedString, collection: true
    attribute :symbols, SymbolPresentations, collection: true
    attribute :quantity_references, QuantityReference, collection: true
    attribute :si_derived_bases, SiDerivedBase, collection: true
    attribute :root_units, RootUnitReference, collection: true
    attribute :references, ExternalReference, collection: true
    attribute :scale_reference, ScaleReference
  end
end
