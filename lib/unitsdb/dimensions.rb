# frozen_string_literal: true

require_relative "dimension"

module Unitsdb
  class Dimensions < Lutaml::Model::Serializable
    # model Config.model_for(:dimensions)

    attribute :dimensions, Dimension, collection: true
  end
end
