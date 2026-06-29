# frozen_string_literal: true

module Unitsdb
  class Database
    # Validates that `short` names and identifier ids are unique
    # within each collection. Encodes the policy of which
    # collections participate in each check via two constants so
    # the intent is explicit.
    #
    #   UniquenessValidator.new(db).validate
    #   # => #<struct short={...}, id={...}>
    class UniquenessValidator
      # Collections that carry a `short` attribute and must be
      # unique-by-short within each collection.
      SHORT_COLLECTIONS = %i[units dimensions unit_systems].freeze

      # Collections whose identifier `id` values must be unique.
      IDENTIFIER_COLLECTIONS = Database::COLLECTIONS

      Result = Struct.new(:short, :id, keyword_init: true) do
        def empty?
          short.empty? && id.empty?
        end
      end

      def initialize(database)
        @database = database
      end

      def validate
        Result.new(
          short: scan_shorts,
          id: scan_identifiers,
        )
      end

      # Convenience entry-point used by Database#validate_uniqueness.
      def self.validate(database)
        result = new(database).validate
        {
          short: result.short,
          id: result.id,
        }
      end

      private

      def scan_shorts
        SHORT_COLLECTIONS.each_with_object({}) do |name, results|
          by_value = {}
          @database.collection(name).each_with_index do |entity, index|
            next unless entity.short

            (by_value[entity.short] ||= []) << "index:#{index}"
          end

          dups = by_value.reject { |_, paths| paths.size == 1 }
          results[name.to_s] = dups unless dups.empty?
        end
      end

      def scan_identifiers
        IDENTIFIER_COLLECTIONS.each_with_object({}) do |name, results|
          by_id = {}
          @database.collection(name).each_with_index do |entity, index|
            entity.identifiers.each_with_index do |identifier, id_index|
              next unless identifier.id

              loc = "index:#{index}:identifiers[#{id_index}]"
              (by_id[identifier.id] ||= []) << loc
            end
          end

          dups = by_id.transform_values(&:uniq).reject { |_, paths| paths.size == 1 }
          results[name.to_s] = dups unless dups.empty?
        end
      end
    end
  end
end
