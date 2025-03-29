# frozen_string_literal: true

module Unitsdb
  class ScaleProperties < Lutaml::Model::Serializable
    # model Config.model_for(:quantity)
    attribute :continuous, :boolean
    attribute :ordered, :boolean
    attribute :logarithmic, :boolean
    attribute :interval, :boolean
    attribute :ratio, :boolean
  end
end
