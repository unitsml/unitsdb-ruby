# frozen_string_literal: true

module Unitsdb
  class PrefixReference < Identifier
    attribute :id, :string
    attribute :type, :string

    def symbolid
      prefix.symbols.first.ascii
    end

    def prefix
      @prefix ||= Unitsdb.prefixes.find_by_id(id)
    end
  end
end
