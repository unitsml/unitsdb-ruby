# frozen_string_literal: true

module Unitsdb
  class QuantityReference < Identifier
    attribute :id, :string
    attribute :type, :string
    attribute :primary, :boolean
  end

  Config.register_model(QuantityReference, id: :quantity_reference)
end
