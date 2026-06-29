# frozen_string_literal: true

module Unitsdb
  class ScaleProperties < Lutaml::Model::Serializable
    attribute :continuous, :boolean
    attribute :ordered, :boolean
    attribute :logarithmic, :boolean
    attribute :interval, :boolean
    attribute :ratio, :boolean
  end

  Config.register_model(ScaleProperties, id: :scale_properties)
end
