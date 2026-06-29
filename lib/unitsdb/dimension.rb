# frozen_string_literal: true

module Unitsdb
  class Dimension < Lutaml::Model::Serializable
    attribute :identifiers, Identifier, collection: true
    attribute :dimensionless, :boolean
    attribute :length, DimensionDetails
    attribute :mass, DimensionDetails
    attribute :time, DimensionDetails
    attribute :electric_current, DimensionDetails
    attribute :thermodynamic_temperature, DimensionDetails
    attribute :amount_of_substance, DimensionDetails
    attribute :luminous_intensity, DimensionDetails
    attribute :plane_angle, DimensionDetails
    attribute :short, :string
    attribute :names, LocalizedString, collection: true
    attribute :references, ExternalReference, collection: true
  end

  Config.register_model(Dimension, id: :dimension)
end
