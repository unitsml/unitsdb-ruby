# frozen_string_literal: true

module Unitsdb
  class PrefixReference < Identifier
    attribute :id, :string
    attribute :type, :string

    def symbolid
      prefix_obj = lookup_prefix
      prefix_obj&.symbols&.first&.ascii
    end

    def prefix
      @prefix ||= lookup_prefix
    end

    private

    def lookup_prefix
      return nil unless Unitsdb.database

      Unitsdb.database.prefixes.find do |p|
        p.identifiers.any? { |i| i.id == id }
      end
    rescue StandardError
      nil
    end
  end
end
