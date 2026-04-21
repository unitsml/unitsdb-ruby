# frozen_string_literal: true

module Unitsdb
  class PrefixReference < Identifier
    attribute :id, :string
    attribute :type, :string
  end

  Config.register_model(PrefixReference, id: :prefix_reference)
end
