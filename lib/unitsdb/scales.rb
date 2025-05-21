# frozen_string_literal: true

require_relative "scale"

module Unitsdb
  class Scales < Lutaml::Model::Serializable
    # model Config.model_for(:Scale)
    attribute :schema_version, :string
    attribute :version, :string
    attribute :scales, Scale, collection: true
  end
end
