# frozen_string_literal: true

module Unitsdb
  class UnitSystem < Lutaml::Model::Serializable
    # model Config.model_for(:unit_system)

    attribute :identifiers, Identifier, collection: true
    attribute :names, LocalizedString, collection: true
    attribute :short, :string
    attribute :acceptable, :boolean
    attribute :references, ExternalReference, collection: true
  end

  Configuration.register_model(UnitSystem, id: :unit_system)
end
