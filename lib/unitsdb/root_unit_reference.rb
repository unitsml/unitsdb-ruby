# frozen_string_literal: true

module Unitsdb
  class RootUnitReference < Lutaml::Model::Serializable
    attribute :power, :integer
    attribute :unit_reference, UnitReference
    attribute :prefix_reference, PrefixReference
  end

  Config.register_model(RootUnitReference, id: :root_unit_reference)
end
