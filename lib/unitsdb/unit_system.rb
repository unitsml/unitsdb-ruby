# frozen_string_literal: true

require_relative "identifier"

module Unitsdb
  class UnitSystem < Lutaml::Model::Serializable
    # model Config.model_for(:unit_system)

    attribute :identifiers, Identifier, collection: true
    attribute :name, :string
    attribute :short, :string
    attribute :acceptable, :boolean
  end
end
