# frozen_string_literal: true

module Unitsdb
  class DimensionReference < Identifier
    attribute :id, :string
    attribute :type, :string
  end

  Config.register_model(DimensionReference, id: :dimension_reference)
end
