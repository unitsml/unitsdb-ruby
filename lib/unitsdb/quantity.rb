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
  class Quantity < Lutaml::Model::Serializable
    attribute :dimension_url, :string
    attribute :quantity_type, :string
    attribute :quantity_name, :string, collection: true
    attribute :unit_reference, UnitReference, collection: true
  end

  class UnitReference < Lutaml::Model::Serializable
    attribute :name, :string
    attribute :url, :string
  end
end
