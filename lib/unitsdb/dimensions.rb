# frozen_string_literal: true

require_relative "dimensions/dimension"

module Unitsdb
  class Dimensions
    include Lutaml::Model::Serialize
    model Config.model_for(:dimensions)

    attribute :dimensions, Dimension, collection: true

    key_value do
      map to: :dimensions, root_mappings: {
        id: :key
      }
    end
  end
end
