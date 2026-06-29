# frozen_string_literal: true

module Unitsdb
  class Dimensions < Lutaml::Model::Serializable
    attribute :schema_version, :string
    attribute :version, :string
    attribute :dimensions, Dimension, collection: true
  end

  Config.register_model(Dimensions, id: :dimensions)
end
