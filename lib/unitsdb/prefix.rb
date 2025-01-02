require_relative "prefix_symbol"
# ---
# NISTp10_30:
#   name: quetta
#   symbol:
#     ascii: Q
#     html: Q
#     latex: Q
#     unicode: Q
#   base: 10
#   power: 30

module Unitsdb
  class Prefix < Lutaml::Model::Serializable
    attribute :id, :string
    attribute :name, :string
    attribute :symbol, PrefixSymbol
    attribute :base, :integer
    attribute :power, :integer

    key_value do
      map :id, to: :id
      map :name, to: :name
      map :symbol, to: :symbol
      map :base, to: :base
      map :power, to: :power
    end
  end
end