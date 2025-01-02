module Unitsdb
  class RootUnit < Lutaml::Model::Serializable
    attribute :unit, :string
    attribute :power_denominator, :integer
    attribute :power_numerator, :integer
    attribute :prefix, :string

    key_value do
      map :unit, to: :unit
      map :power_denominator, to: :power_denominator
      map :power_numerator, to: :power_numerator
      map :prefix, to: :prefix
    end
  end
end
