# frozen_string_literal: true

require_relative "unit_reference"

# # Quantities
# NISTq156:
#   dimension_url: "#NISTd68"
#   quantity_type: derived
#   quantity_name:
#       - linear expansion coefficient
#   unit_reference:
#       - name: kelvin to the power minus one
#         url: "#NISTu5e-1/1"

# NISTq155:
#   dimension_url: "#NISTd57"
#   quantity_type: derived
#   quantity_name:
#     - area moment of inertia
#     - second moment of area
#   unit_reference:
#     - name: inch to the fourth power
#       url: "#NISTu208"

module Unitsdb
  class Quantities
    class Quantity < Lutaml::Model::Serializable
      model Config.model_for(:quantity)

      attribute :id, :string
      attribute :dimension_url, :string
      attribute :quantity_type, :string
      attribute :quantity_name, :string, collection: true
      attribute :unit_reference, UnitReference, collection: true
    end
  end
end
