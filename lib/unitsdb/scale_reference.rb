# frozen_string_literal: true

module Unitsdb
  class ScaleReference < Identifier
    attribute :id, :string
    attribute :type, :string
  end

  Configuration.register_model(ScaleReference, id: :scale_reference)
end
