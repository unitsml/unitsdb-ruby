# frozen_string_literal: true

module Unitsdb
  class Scales < Lutaml::Model::Serializable
    # model Config.model_for(:Scale)
    attribute :schema_version, :string
    attribute :version, :string
    attribute :scales, Scale, collection: true
  end

  Configuration.register_model(Scales, id: :scales)
end
