# frozen_string_literal: true

require_relative "unit"

module Unitsdb
  class Units < Lutaml::Model::Serializable
    # model Config.model_for(:units)

    attribute :schema_version, :string
    attribute :version, :string
    attribute :units, Unit, collection: true
  end
end
