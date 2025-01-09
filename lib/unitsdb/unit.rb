# frozen_string_literal: true

require_relative "unit_system"
require_relative "unit_symbol"
require_relative "root_units"
require_relative "si_derived_base"
require_relative "quantity_reference"

# "NISTu10":
#   dimension_url: "#NISTd9"
#   short: steradian
#   root: true
#   unit_system:
#     type: "SI_derived_special"
#     name: "SI"
#   unit_name:
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
#         power_numerator: 1
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
    attribute :id, :string
    attribute :short, :string
    attribute :root, :boolean
    attribute :prefixed, :boolean
    attribute :dimension_url, :string
    attribute :unit_system, UnitSystem, collection: true
    attribute :unit_name, :string, collection: true
    attribute :unit_symbol, UnitSymbol, collection: true
    attribute :root_units, RootUnits, collection: true
    attribute :quantity_reference, QuantityReference, collection: true
    attribute :si_derived_bases, SiDerivedBase, collection: true

    key_value do
      map :id, to: :id
      map :dimension_url, to: :dimension_url
      map :short, to: :short, render_nil: true
      map :root, to: :root
      map :prefixed, to: :prefixed
      map :unit_system, to: :unit_system
      map :unit_name, to: :unit_name
      map :unit_symbols, to: :unit_symbol
      map :root_units, to: :root_units
      map :quantity_reference, to: :quantity_reference
      map :si_derived_bases, to: :si_derived_bases
    end
  end
end
