# frozen_string_literal: true

module Unitsdb
  class Dimensions < Lutaml::Model::Serializable
    # model Config.model_for(:dimensions)

    attribute :schema_version, :string
    attribute :version, :string
    attribute :dimensions, Dimension, collection: true
  end

  Configuration.register_model(Dimensions, id: :dimensions)
end
