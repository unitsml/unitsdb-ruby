# frozen_string_literal: true

module Unitsdb
  class Units < Lutaml::Model::Serializable
    # model Config.model_for(:units)

    attribute :schema_version, :string
    attribute :version, :string
    attribute :units, Unit, collection: true
  end

  Configuration.register_model(Units, id: :units)
end
