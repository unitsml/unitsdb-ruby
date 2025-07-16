# frozen_string_literal: true

require_relative "identifier"
require_relative "localized_string"
require_relative "external_reference"

module Unitsdb
  class UnitSystem < Lutaml::Model::Serializable
    # model Config.model_for(:unit_system)

    attribute :identifiers, Identifier, collection: true
    attribute :names, LocalizedString, collection: true
    attribute :short, :string
    attribute :acceptable, :boolean
    attribute :references, ExternalReference, collection: true
  end
end
