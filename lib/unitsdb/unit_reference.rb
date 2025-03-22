# frozen_string_literal: true

require_relative "identifier"

module Unitsdb
  class UnitReference < Identifier
    attribute :id, :string
    attribute :type, :string
  end
end
