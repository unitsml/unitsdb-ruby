# frozen_string_literal: true

module Unitsdb
  class QuantityReference < Identifier
    # model Config.model_for(:quantity_reference)

    attribute :id, :string
    attribute :type, :string
  end

  Configuration.register_model(QuantityReference, id: :quantity_reference)
end
