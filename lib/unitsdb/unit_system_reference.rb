# frozen_string_literal: true

require_relative "identifier"

module Unitsdb
  class UnitSystemReference < Identifier
    attribute :id, :string
    attribute :type, :string
  end
end
