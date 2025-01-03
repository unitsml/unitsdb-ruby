# frozen_string_literal: true

require_relative "root_unit"

module Unitsdb
  class RootUnits < Lutaml::Model::Serializable
    attribute :unit, :string
    attribute :power_denominator, :integer
    attribute :power_numerator, :integer
    attribute :enumerated_root_units, RootUnit, collection: true

    key_value do
      map :unit, to: :unit
      map :power_denominator, to: :power_denominator
      map :power_numerator, to: :power_numerator
      map :enumerated_root_units,
          to: :enumerated_root_units
    end
  end
end
