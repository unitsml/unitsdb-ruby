# frozen_string_literal: true

require_relative "dimension"

module Unitsdb
  class Dimensions < Lutaml::Model::Serializable
    attribute :dimension, Dimension, collection: true

    key_value do
      map to: :dimension, root_mappings: {
            id: :key,
          }
    end
  end
end
