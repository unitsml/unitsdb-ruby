require_relative "unit"

module Unitsdb
  class Units < Lutaml::Model::Serializable
    attribute :units, Unit, collection: true

    key_value do
      map :units, :units, child_mappings: {
                        id: :key,
                      }
    end
  end
end
