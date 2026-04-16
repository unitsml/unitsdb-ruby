# frozen_string_literal: true

module Unitsdb
  class UnitSystemReference < Identifier
    attribute :id, :string
    attribute :type, :string
  end

  Configuration.register_model(UnitSystemReference, id: :unit_system_reference)
end
