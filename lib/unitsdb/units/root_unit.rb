# frozen_string_literal: true

module Unitsdb
  class Units
    class RootUnit < Lutaml::Model::Serializable
      model Config.model_for(:root_unit)

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
end
