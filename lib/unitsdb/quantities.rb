# frozen_string_literal: true

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

require_relative "quantity"

module Unitsdb
  class Quantities < Lutaml::Model::Serializable
    attribute :quantity, Quantity, collection: true

    key_value do
      map to: :quantity, root_mappings: {
        id: :key
      }
    end
  end
end
