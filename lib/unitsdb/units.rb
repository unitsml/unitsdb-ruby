# frozen_string_literal: true

require_relative "unit"

module Unitsdb
  class Units < Lutaml::Model::Serializable
    attribute :units, Unit, collection: true

    key_value do
      map to: :units, root_mappings: {
            id: :key,
          }
    end
  end
end
