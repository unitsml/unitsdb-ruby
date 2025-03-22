# frozen_string_literal: true

require_relative "unit_reference"
require_relative "prefix_reference"

module Unitsdb
  class RootUnitReference < Lutaml::Model::Serializable
    # model Config.model_for(:root_unit)

    attribute :power, :integer
    attribute :unit_reference, UnitReference
    attribute :prefix_reference, PrefixReference
  end
end
