# frozen_string_literal: true

module Unitsdb
  class Scale < Lutaml::Model::Serializable
    # model Config.model_for(:quantity)

    attribute :identifiers, Identifier, collection: true
    attribute :names, LocalizedString, collection: true
    attribute :description, LocalizedString, collection: true
    attribute :short, :string
    attribute :properties, ScaleProperties
  end

  Config.register_model(Scale, id: :scale)
end
