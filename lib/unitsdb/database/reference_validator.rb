# frozen_string_literal: true

module Unitsdb
  class Database
    # Validates that every cross-entity reference in a Database points
    # at an entity that actually exists. Single source of truth for
    # both `Database#validate_references` and the
    # `unitsdb validate references` CLI command.
    #
    # Composition:
    #   ReferenceValidator    — public façade; returns a Result
    #   IdRegistry            — builds {type => {key => path}} from db
    #   ReferenceChecker      — walks each reference kind
    #   LookupStrategies      — pluggable "is this ref valid?" predicates
    class ReferenceValidator
      # @return [Hash] empty if all refs valid; otherwise
      #   { file_type => { ref_path => { id:, type:, ref_type: } } }
      Result = Struct.new(:invalid, keyword_init: true) do
        def empty?
          invalid.empty?
        end
      end

      def initialize(database)
        @database = database
      end

      def validate
        registry = IdRegistry.build(@database)
        checker = ReferenceChecker.new(registry, LookupStrategies::ALL)
        Result.new(invalid: checker.check_all(@database))
      end

      # Convenience entry-point used by Database#validate_references.
      def self.validate(database)
        new(database).validate.invalid
      end
    end

    # Builds a {collection_type => {ref_key => path}} registry
    # covering identifiers (composite-keyed and bare-id keyed) plus
    # short-name lookups for dimensions and unit_systems.
    class IdRegistry
      def self.build(database)
        new(database).build
      end

      def initialize(database)
        @database = database
      end

      def build
        registry = {}
        Database::COLLECTIONS.each do |name|
          registry[name.to_s] = {}
          add_identifiers(registry, name)
        end
        add_short_names(registry, :dimensions, "dimensions_short")
        add_short_names(registry, :unit_systems, "unit_systems_short")
        registry
      end

      private

      def add_identifiers(registry, collection_name)
        collection = @database.collection(collection_name)
        collection.each_with_index do |entity, index|
          entity.identifiers.each do |identifier|
            next unless identifier.id && identifier.type

            composite = "#{identifier.type}:#{identifier.id}"
            registry[collection_name.to_s][composite] = "index:#{index}"
            registry[collection_name.to_s][identifier.id] = "index:#{index}"
          end
        end
      end

      def add_short_names(registry, collection_name, key)
        registry[key.to_s] = {}
        @database.collection(collection_name).each_with_index do |entity, idx|
          next unless entity.short

          registry[key.to_s][entity.short] = "index:#{idx}"
        end
      end
    end

    # Walks each reference kind in the Database and records invalid
    # references via the supplied lookup strategies.
    class ReferenceChecker
      def initialize(registry, strategies)
        @registry = registry
        @strategies = strategies
      end

      def check_all(database)
        invalid = {}
        check_unit_system_references(database, invalid)
        check_quantity_references(database, invalid)
        check_root_unit_references(database, invalid)
        invalid
      end

      private

      def check_unit_system_references(database, invalid)
        database.units.each_with_index do |unit, index|
          refs = unit.unit_system_reference
          next unless refs

          refs.each_with_index do |ref, idx|
            validate(ref, "unit_systems", "units",
                     "units:index:#{index}:unit_system_reference[#{idx}]", invalid)
          end
        end
      end

      def check_quantity_references(database, invalid)
        database.units.each_with_index do |unit, index|
          refs = unit.quantity_references
          next unless refs

          refs.each_with_index do |ref, idx|
            validate(ref, "quantities", "units",
                     "units:index:#{index}:quantity_references[#{idx}]", invalid)
          end
        end
      end

      def check_root_unit_references(database, invalid)
        database.units.each_with_index do |unit, index|
          refs = unit.root_units
          next unless refs

          refs.each_with_index do |root_unit, idx|
            if root_unit.unit_reference
              validate(root_unit.unit_reference, "units", "units",
                       "units:index:#{index}:root_units.#{idx}.unit_reference",
                       invalid)
            end

            next unless root_unit.prefix_reference

            validate(root_unit.prefix_reference, "prefixes", "units",
                     "units:index:#{index}:root_units.#{idx}.prefix_reference",
                     invalid)
          end
        end
      end

      def validate(ref, ref_type, file_type, ref_path, invalid)
        pair = Reference.destructure(ref)
        valid = if pair
                  any_strategy_matches?(pair, ref_type)
                else
                  @registry.key?(ref_type) && @registry[ref_type].key?(ref)
                end

        return if valid

        invalid[file_type] ||= {}
        invalid[file_type][ref_path] = if pair
                                         { id: pair.id, type: pair.type, ref_type: ref_type }
                                       else
                                         { id: ref, type: ref_type }
                                       end
      end

      def any_strategy_matches?(pair, ref_type)
        @strategies.any? { |s| s.call(pair, ref_type, @registry) }
      end
    end

    # A normalized reference pair. `id` and `type` are strings.
    ReferencePair = Struct.new(:id, :type, keyword_init: true)

    # Coerces various reference shapes (Identifier instance, Hash with
    # string keys, plain String) into a ReferencePair (or nil if the
    # ref is a bare string with no type metadata).
    module Reference
      module_function

      def destructure(ref)
        case ref
        when Unitsdb::Identifier
          ReferencePair.new(id: ref.id, type: ref.type) if ref.id && ref.type
        when Hash
          ReferencePair.new(id: ref["id"], type: ref["type"]) if ref["id"] && ref["type"]
        end
      end
    end

    # Lookup strategies. Each is a proc that takes (pair, ref_type,
    # registry) and returns true if the reference is valid under that
    # strategy. Composed in ALL and tried in order by ReferenceChecker.
    module LookupStrategies
      # Exact "#{type}:#{id}" match.
      COMPOSITE_KEY = ->(pair, ref_type, registry) do
        registry.key?(ref_type) && registry[ref_type].key?("#{pair.type}:#{pair.id}")
      end

      # Bare-id match (any type). For backward compatibility with
      # databases that only stored the id without the type.
      BARE_ID = ->(pair, ref_type, registry) do
        registry.key?(ref_type) && registry[ref_type].key?(pair.id)
      end

      # Unit-system alternate IDs. The UnitsML `unitsml` authority uses
      # kebab-case (`si-base`) while NIST uses snake-case (`SI_base`).
      # Accept either form when resolving unit_system references.
      UNIT_SYSTEM_ALTERNATE = ->(pair, ref_type, registry) do
        next false unless ref_type == "unit_systems" && pair.type == "unitsml"
        next false unless registry.key?(ref_type)

        alternates = []
        alternates << pair.id
        alternates << "SI_#{pair.id.sub('si-', '')}" if pair.id.start_with?("si-")
        alternates << "non-SI_#{pair.id.sub('nonsi-', '')}" if pair.id.start_with?("nonsi-")

        keys = registry[ref_type].keys
        alternates.any? { |alt| keys.any? { |k| k.end_with?(":#{alt}") } }
      end

      ALL = [COMPOSITE_KEY, BARE_ID, UNIT_SYSTEM_ALTERNATE].freeze
    end
  end
end
