# frozen_string_literal: true

module Unitsdb
  class UnitReference < Identifier
    attribute :id, :string
    attribute :type, :string
  end

  Configuration.register_model(UnitReference, id: :unit_reference)
end
