# frozen_string_literal: true

require_relative "root_unit"

module Unitsdb
  class Units
    class RootUnits < Lutaml::Model::Serializable
      model Config.model_for(:root_units)

      attribute :enumerated_root_units, RootUnit, collection: true

      key_value do
        map :enumerated_root_units,
            to: :enumerated_root_units
      end
    end
  end
end
