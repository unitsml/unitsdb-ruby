module Unitsdb
  class RootUnits < Lutaml::Model::Serializable
    attribute :unit, :string
    attribute :power_denominator, :integer
    attribute :power_numerator, :integer
  end
end
