# frozen_string_literal: true

require "unitsdb/units/unit"

module Unitsdb
  class Units
    include Lutaml::Model::Serialize
    model Config.model_for(:units)

    attribute :units, Unit, collection: true

    key_value do
      map to: :units, root_mappings: {
            id: :key,
          }
    end
  end
end
