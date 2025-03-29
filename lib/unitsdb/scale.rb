# frozen_string_literal: true

require_relative "identifier"
require_relative "localized_string"
require_relative "scale_properties"

module Unitsdb
  class Scale < Lutaml::Model::Serializable
    # model Config.model_for(:quantity)

    attribute :identifiers, Identifier, collection: true
    attribute :names, LocalizedString, collection: true
    attribute :description, LocalizedString, collection: true
    attribute :short, :string
    attribute :properties, ScaleProperties
  end
end
