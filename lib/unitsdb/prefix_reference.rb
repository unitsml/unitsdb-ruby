# frozen_string_literal: true

require_relative "identifier"

module Unitsdb
  class PrefixReference < Identifier
    attribute :id, :string
    attribute :type, :string
  end
end
