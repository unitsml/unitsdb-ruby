# frozen_string_literal: true

module Unitsdb
  class Database < Lutaml::Model::Serializable
    autoload :ReferenceValidator, "unitsdb/database/reference_validator"
    autoload :UniquenessValidator, "unitsdb/database/uniqueness_validator"
    autoload :Loader, "unitsdb/database/loader"

    COLLECTIONS = Loader::DATABASE_FILES.keys.map(&:to_sym).freeze

    # Collections whose entities carry a `symbols` attribute.
    # Used by symbol-based search/match to narrow iteration.
    SYMBOL_COLLECTIONS = %i[units prefixes].freeze

    attribute :schema_version, :string
    attribute :version, :string
    attribute :units, Unit, collection: true
    attribute :prefixes, Prefix, collection: true
    attribute :quantities, Quantity, collection: true
    attribute :dimensions, Dimension, collection: true
    attribute :unit_systems, UnitSystem, collection: true

    # Resolve a collection name (String or Symbol) to its typed Array.
    # Validates against COLLECTIONS so caller-supplied names can never
    # dispatch to arbitrary methods (e.g. `schema_version`, `to_yaml`).
    def collection(name)
      sym = name.to_sym
      unless COLLECTIONS.include?(sym)
        raise ArgumentError, "unknown collection: #{name.inspect}"
      end

      public_send(sym)
    end

    # Build an empty Database with `entities` partitioned into their
    # typed collections. Used by CLI commands that need to serialize
    # a subset of search results.
    def self.empty_for_results(entities)
      Database.new.tap do |db|
        COLLECTIONS.each do |name|
          klass = collection_element_class(name)
          db.public_send("#{name}=", entities.grep(klass))
        end
      end
    end

    class << self
      private

      # Map a collection symbol to the entity class it holds.
      # Derived from the Lutaml attribute declaration.
      def collection_element_class(name)
        attributes.fetch(name.to_s).type
      end
    end

    # Find an entity by its specific identifier and type
    # @param id [String] the identifier value to search for
    # @param type [String, Symbol] the entity type (units, prefixes, quantities, etc.)
    # @return [Object, nil] the first entity with matching identifier or nil if not found
    def find_by_type(id:, type:)
      collection(type).find do |entity|
        entity.identifiers.any? { |identifier| identifier.id == id }
      end
    end

    # Find an entity by its identifier id across all entity types
    # @param id [String] the identifier value to search for
    # @param type [String, nil] optional identifier type to match
    # @return [Object, nil] the first entity with matching identifier or nil if not found
    def get_by_id(id:, type: nil)
      COLLECTIONS.each do |name|
        entity = collection(name).find do |e|
          e.identifiers.any? do |identifier|
            identifier.id == id && (type.nil? || identifier.type == type)
          end
        end
        return entity if entity
      end

      nil
    end

    # Search for entities containing the given text in identifiers,
    # names, or short description.
    # @param params [Hash] search parameters
    # @option params [String] :text The text to search for
    # @option params [String, Symbol, nil] :type Optional entity type to limit search scope
    # @return [Array] all entities matching the search criteria
    def search(params = {})
      text = params[:text]
      return [] unless text

      needle = text.downcase
      scope = scope_for(params[:type], COLLECTIONS)

      scope.each_with_object([]) do |name, results|
        collection(name).each do |entity|
          results << entity if matches_text?(entity, needle)
        end
      end
    end

    # Find entities by symbol
    # @param symbol [String] the symbol to search for (exact match, case-insensitive)
    # @param entity_type [String, Symbol, nil] the entity type to search (units or prefixes)
    # @return [Array] entities with matching symbol
    def find_by_symbol(symbol, entity_type = nil)
      return [] unless symbol

      needle = symbol.downcase
      scope = scope_for(entity_type, SYMBOL_COLLECTIONS)

      scope.each_with_object([]) do |name, results|
        collection(name).each do |entity|
          results << entity if entity.symbols.any? do |sym|
            sym.ascii.to_s.downcase == needle
          end
        end
      end
    end

    # Match entities by name, short, or symbol with different match types
    # @param params [Hash] match parameters
    # @option params [String] :value The value to match against
    # @option params [String, Symbol] :match_type The type of match to perform (exact, symbol)
    # @option params [String, Symbol, nil] :entity_type Optional entity type to limit search scope
    # @return [Hash] matches grouped by match type (exact, symbol_match) with match details
    def match_entities(params = {})
      value = params[:value]
      return {} unless value

      match_type = params[:match_type]&.to_s || "exact"
      result = { exact: [], symbol_match: [] }

      scope_for(params[:entity_type], COLLECTIONS).each do |name|
        collection(name).each do |entity|
          if %w[exact all].include?(match_type)
            match_exact(entity, value, result)
          end
          next unless %w[symbol all].include?(match_type) && SYMBOL_COLLECTIONS.include?(name)

          match_symbol(entity, value, result)
        end
      end

      result.delete_if { |_, v| v.empty? }
      result
    end

    # Checks for uniqueness of identifiers and short names.
    # Delegates to UniquenessValidator.
    def validate_uniqueness
      UniquenessValidator.validate(self)
    end

    # Validates references between entities. Delegates to ReferenceValidator.
    def validate_references
      ReferenceValidator.validate(self)
    end

    private

    # Resolve a caller-supplied type to a list of collection symbols,
    # validating against `allowed`. Nil means "all allowed".
    def scope_for(type, allowed)
      return allowed.dup unless type

      sym = type.to_sym
      raise ArgumentError, "unknown collection: #{type.inspect}" unless allowed.include?(sym)

      [sym]
    end

    def matches_text?(entity, needle)
      entity.identifiers.any? { |i| i.id.to_s.downcase.include?(needle) } ||
        entity.names.any? { |n| n.value.to_s.downcase.include?(needle) } ||
        entity.short.to_s.downcase.include?(needle)
    end

    def match_exact(entity, value, result)
      if entity.short && entity.short.downcase == value.downcase
        result[:exact] << {
          entity: entity,
          match_desc: "short_to_name",
          details: "UnitsDB short '#{entity.short}' matches '#{value}'",
        }
        return
      end

      matching_name = entity.names.find do |name|
        name.value.to_s.downcase == value.downcase
      end
      return unless matching_name

      result[:exact] << {
        entity: entity,
        match_desc: "name_to_name",
        details: "UnitsDB name '#{matching_name.value}' (#{matching_name.lang}) matches '#{value}'",
      }
    end

    def match_symbol(entity, value, result)
      matching_symbol = entity.symbols.find do |sym|
        sym.ascii.to_s.downcase == value.downcase
      end
      return unless matching_symbol

      result[:symbol_match] << {
        entity: entity,
        match_desc: "symbol_match",
        details: "UnitsDB symbol '#{matching_symbol.ascii}' matches '#{value}'",
      }
    end

    class << self
      # Load every YAML file under `dir_path` and deserialize into a
      # Database instance scoped to `context`. The default context is
      # auto-created via `Config.ensure_default_context!`; custom
      # contexts must be created by the caller first.
      def from_db(dir_path, context: Unitsdb::Config.context_id)
        context_id = context.to_sym
        Unitsdb::Config.ensure_default_context! if context_id == Unitsdb::Config.context_id

        combined_hash = Loader.load(dir_path)

        Lutaml::Model::GlobalContext.with_context(context_id) do
          if Unitsdb::Config.register_id_for(context_id)
            from_hash(combined_hash, register: context_id)
          else
            from_hash(combined_hash)
          end
        end
      end
    end
  end

  Config.register_model(Database, id: :database)
end
