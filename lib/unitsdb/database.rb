# frozen_string_literal: true

module Unitsdb
  class Database < Lutaml::Model::Serializable
    # model Config.model_for(:units)

    DATABASE_FILES = {
      "prefixes" => "prefixes.yaml",
      "dimensions" => "dimensions.yaml",
      "units" => "units.yaml",
      "quantities" => "quantities.yaml",
      "unit_systems" => "unit_systems.yaml",
    }.freeze
    SUPPORTED_SCHEMA_VERSION = "2.0.0"

    attribute :schema_version, :string
    attribute :version, :string
    attribute :units, Unit, collection: true
    attribute :prefixes, Prefix, collection: true
    attribute :quantities, Quantity, collection: true
    attribute :dimensions, Dimension, collection: true
    attribute :unit_systems, UnitSystem, collection: true

    # Find an entity by its specific identifier and type
    # @param id [String] the identifier value to search for
    # @param type [String, Symbol] the entity type (units, prefixes, quantities, etc.)
    # @return [Object, nil] the first entity with matching identifier or nil if not found
    def find_by_type(id:, type:)
      collection = send(type.to_s)
      collection.find do |entity|
        entity.identifiers&.any? do |identifier|
          identifier.id == id
        end
      end
    end

    # Find an entity by its identifier id across all entity types
    # @param id [String] the identifier value to search for
    # @param type [String, nil] optional identifier type to match
    # @return [Object, nil] the first entity with matching identifier or nil if not found
    def get_by_id(id:, type: nil)
      %w[units prefixes quantities dimensions
         unit_systems].each do |collection_name|
        next unless respond_to?(collection_name)

        collection = send(collection_name)
        entity = collection.find do |e|
          e.identifiers&.any? do |identifier|
            identifier.id == id && (type.nil? || identifier.type == type)
          end
        end

        return entity if entity
      end

      nil
    end

    # Search for entities containing the given text in identifiers, names, or short description
    # @param params [Hash] search parameters
    # @option params [String] :text The text to search for
    # @option params [String, Symbol, nil] :type Optional entity type to limit search scope
    # @return [Array] all entities matching the search criteria
    def search(params = {})
      text = params[:text]
      type = params[:type]

      return [] unless text

      results = []

      # Define which collections to search based on type parameter
      collections = if type
                      [type.to_s]
                    else
                      %w[units prefixes quantities
                         dimensions unit_systems]
                    end

      collections.each do |collection_name|
        next unless respond_to?(collection_name)

        collection = send(collection_name)
        collection.each do |entity|
          # Search in identifiers
          if entity.identifiers&.any? do |identifier|
            identifier.id.to_s.downcase.include?(text.downcase)
          end
            results << entity
            next
          end

          # Search in names (if the entity has names)
          if entity.respond_to?(:names) && entity.names && entity.names.any? do |name|
            name.value.to_s.downcase.include?(text.downcase)
          end
            results << entity
            next
          end

          # Search in short description
          if entity.respond_to?(:short) && entity.short &&
              entity.short.to_s.downcase.include?(text.downcase)
            results << entity
            next
          end

          # Special case for prefix name (prefixes don't have names array)
          next unless collection_name == "prefixes" && entity.respond_to?(:name) &&
            entity.name.to_s.downcase.include?(text.downcase)

          results << entity
          next
        end
      end

      results
    end

    # Find entities by symbol
    # @param symbol [String] the symbol to search for (exact match, case-insensitive)
    # @param entity_type [String, Symbol, nil] the entity type to search (units or prefixes)
    # @return [Array] entities with matching symbol
    def find_by_symbol(symbol, entity_type = nil)
      return [] unless symbol

      results = []

      # Symbol search only applies to units and prefixes
      collections = entity_type ? [entity_type.to_s] : %w[units prefixes]

      collections.each do |collection_name|
        next unless respond_to?(collection_name) && %w[units
                                                       prefixes].include?(collection_name)

        collection = send(collection_name)
        collection.each do |entity|
          if collection_name == "units" && entity.respond_to?(:symbols) && entity.symbols
            # Units can have multiple symbols
            matches = entity.symbols.any? do |sym|
              sym.respond_to?(:ascii) && sym.ascii &&
                sym.ascii.downcase == symbol.downcase
            end

            results << entity if matches
          elsif collection_name == "prefixes" && entity.respond_to?(:symbols) && entity.symbols
            # Prefixes have multiple symbols in 2.0.0
            matches = entity.symbols.any? do |sym|
              sym.respond_to?(:ascii) && sym.ascii &&
                sym.ascii.downcase == symbol.downcase
            end

            results << entity if matches
          end
        end
      end

      results
    end

    # Match entities by name, short, or symbol with different match types
    # @param params [Hash] match parameters
    # @option params [String] :value The value to match against
    # @option params [String, Symbol] :match_type The type of match to perform (exact, symbol)
    # @option params [String, Symbol, nil] :entity_type Optional entity type to limit search scope
    # @return [Hash] matches grouped by match type (exact, symbol_match) with match details
    def match_entities(params = {})
      value = params[:value]
      match_type = params[:match_type]&.to_s || "exact"
      entity_type = params[:entity_type]

      return {} unless value

      result = {
        exact: [],
        symbol_match: [],
      }

      # Define collections to search based on entity_type parameter
      collections = if entity_type
                      [entity_type.to_s]
                    else
                      %w[units prefixes
                         quantities dimensions unit_systems]
                    end

      collections.each do |collection_name|
        next unless respond_to?(collection_name)

        collection = send(collection_name)

        collection.each do |entity|
          # For exact matches - look at short and names
          if %w[exact all].include?(match_type)
            # Match by short
            if entity.respond_to?(:short) && entity.short &&
                entity.short.downcase == value.downcase
              result[:exact] << {
                entity: entity,
                match_desc: "short_to_name",
                details: "UnitsDB short '#{entity.short}' matches '#{value}'",
              }
              next
            end

            # Match by names
            if entity.respond_to?(:names) && entity.names
              matching_name = entity.names.find do |name|
                name.value.to_s.downcase == value.downcase
              end
              if matching_name
                result[:exact] << {
                  entity: entity,
                  match_desc: "name_to_name",
                  details: "UnitsDB name '#{matching_name.value}' (#{matching_name.lang}) matches '#{value}'",
                }
                next
              end
            end
          end

          # For symbol matches - only applicable to units and prefixes
          if %w[symbol all].include?(match_type) &&
              %w[units prefixes].include?(collection_name)
            if collection_name == "units" && entity.respond_to?(:symbols) && entity.symbols
              # Units can have multiple symbols
              matching_symbol = entity.symbols.find do |sym|
                sym.respond_to?(:ascii) && sym.ascii &&
                  sym.ascii.downcase == value.downcase
              end

              if matching_symbol
                result[:symbol_match] << {
                  entity: entity,
                  match_desc: "symbol_match",
                  details: "UnitsDB symbol '#{matching_symbol.ascii}' matches '#{value}'",
                }
              end
            elsif collection_name == "prefixes" && entity.respond_to?(:symbols) && entity.symbols
              # Prefixes have multiple symbols in 2.0.0
              matching_symbol = entity.symbols.find do |sym|
                sym.respond_to?(:ascii) && sym.ascii &&
                  sym.ascii.downcase == value.downcase
              end

              if matching_symbol
                result[:symbol_match] << {
                  entity: entity,
                  match_desc: "symbol_match",
                  details: "UnitsDB symbol '#{matching_symbol.ascii}' matches '#{value}'",
                }
              end
            end
          end
        end
      end

      # Remove empty categories
      result.delete_if { |_, v| v.empty? }

      result
    end

    # Checks for uniqueness of identifiers and short names
    def validate_uniqueness
      results = {
        short: {},
        id: {},
      }

      # Validate short names for applicable collections
      validate_shorts(units, "units", results)
      validate_shorts(dimensions, "dimensions", results)
      validate_shorts(unit_systems, "unit_systems", results)

      # Validate identifiers for all collections
      validate_identifiers(units, "units", results)
      validate_identifiers(prefixes, "prefixes", results)
      validate_identifiers(quantities, "quantities", results)
      validate_identifiers(dimensions, "dimensions", results)
      validate_identifiers(unit_systems, "unit_systems", results)

      results
    end

    # Validates references between entities
    def validate_references
      invalid_refs = {}

      # Build registry of all valid IDs first
      registry = build_id_registry

      # Check various reference types
      check_dimension_references(registry, invalid_refs)
      check_unit_system_references(registry, invalid_refs)
      check_quantity_references(registry, invalid_refs)
      check_root_unit_references(registry, invalid_refs)

      invalid_refs
    end

    def self.from_db(dir_path, context: Unitsdb::Config.context_id)
      context_id = context.to_sym
      if context_id == Unitsdb::Config.context_id &&
          Unitsdb::Config.find_context(context_id).nil?
        Unitsdb::Config.context(context_id)
      end

      db_path = File.expand_path(dir_path.to_s)
      unless Dir.exist?(db_path)
        raise Errors::DatabaseNotFoundError,
              "Database directory not found: #{db_path}"
      end

      missing_files = DATABASE_FILES.values.reject do |filename|
        File.exist?(File.join(db_path, filename))
      end

      if missing_files.any?
        raise Errors::DatabaseFileNotFoundError,
              "Missing required database files: #{missing_files.join(', ')}"
      end

      documents = load_database_documents(db_path)
      schema_version = validate_schema_versions!(documents)
      combined_hash = build_database_hash(documents, schema_version)

      Lutaml::Model::GlobalContext.with_context(context_id) do
        if Unitsdb::Config.register(context_id)
          from_hash(combined_hash, register: context_id)
        else
          from_hash(combined_hash)
        end
      end
    end

    def self.load_database_documents(db_path)
      puts "[UnitsDB] Loading YAML files from directory: #{db_path}" if ENV["UNITSDB_DEBUG"]
      DATABASE_FILES.transform_values do |filename|
        puts "  - #{File.join(db_path, filename)}" if ENV["UNITSDB_DEBUG"]
        load_database_yaml(File.join(db_path, filename), filename)
      end
    end

    def self.load_database_yaml(path, filename)
      document = YAML.safe_load_file(path)

      unless document.is_a?(Hash)
        raise Errors::DatabaseFileInvalidError,
              "Invalid YAML structure in #{filename}: expected a mapping"
      end

      document
    rescue Errno::ENOENT => e
      raise Errors::DatabaseFileNotFoundError,
            "Failed to read database file: #{e.message}"
    rescue Psych::SyntaxError => e
      raise Errors::DatabaseFileInvalidError,
            "Invalid YAML in database file: #{e.message}"
    rescue Errors::DatabaseError
      raise
    rescue StandardError => e
      raise Errors::DatabaseLoadError,
            "Error loading database file #{filename}: #{e.message}"
    end
    private_class_method :load_database_documents, :load_database_yaml

    def self.validate_schema_versions!(documents)
      versions = DATABASE_FILES.each_with_object({}) do |(collection_key, filename), result|
        document = documents.fetch(collection_key)
        result[filename] = document.fetch("schema_version")
      rescue KeyError
        raise Errors::DatabaseFileInvalidError,
              "Missing schema_version in #{filename}"
      end

      unless versions.values.uniq.size == 1
        raise Errors::VersionMismatchError,
              "Version mismatch in database files: #{versions.inspect}"
      end

      version = versions.values.first
      unless version == SUPPORTED_SCHEMA_VERSION
        raise Errors::UnsupportedVersionError,
              "Unsupported database version: #{version}. Only version #{SUPPORTED_SCHEMA_VERSION} is supported."
      end

      version
    end

    def self.build_database_hash(documents, schema_version)
      {
        "schema_version" => schema_version,
      }.merge(
        DATABASE_FILES.keys.to_h do |collection_key|
          document = documents.fetch(collection_key)
          [collection_key, fetch_collection!(document, collection_key)]
        end,
      )
    end

    def self.fetch_collection!(document, collection_key)
      document.fetch(collection_key)
    rescue KeyError
      raise Errors::DatabaseFileInvalidError,
            "Missing #{collection_key} collection in #{DATABASE_FILES.fetch(collection_key)}"
    end
    private_class_method :validate_schema_versions!, :build_database_hash,
                         :fetch_collection!

    private

    # Helper methods for uniqueness validation
    def validate_shorts(collection, type, results)
      shorts = {}

      collection.each_with_index do |item, index|
        next unless item.respond_to?(:short) && item.short

        (shorts[item.short] ||= []) << "index:#{index}"
      end

      # Add to results if duplicates found
      shorts.each do |short, paths|
        next unless paths.size > 1

        (results[:short][type] ||= {})[short] = paths
      end
    end

    def validate_identifiers(collection, type, results)
      ids = {}

      collection.each_with_index do |item, index|
        next unless item.respond_to?(:identifiers)

        # Process identifiers array for this item
        item.identifiers.each_with_index do |identifier, id_index|
          next unless identifier.respond_to?(:id) && identifier.id

          id_key = identifier.id
          loc = "index:#{index}:identifiers[#{id_index}]"
          (ids[id_key] ||= []) << loc
        end
      end

      # Add duplicates to results
      ids.each do |id, paths|
        unique_paths = paths.uniq
        next unless unique_paths.size > 1

        (results[:id][type] ||= {})[id] = unique_paths
      end
    end

    # Helper methods for reference validation
    def build_id_registry
      registry = {}

      # Add unit identifiers
      registry["units"] = {}
      units.each_with_index do |unit, index|
        next unless unit.respond_to?(:identifiers)

        unit.identifiers.each do |identifier|
          next unless identifier.id && identifier.type

          # Add composite key (type:id)
          composite_key = "#{identifier.type}:#{identifier.id}"
          registry["units"][composite_key] = "index:#{index}"

          # Also add just the ID for backward compatibility
          registry["units"][identifier.id] = "index:#{index}"
        end
      end

      # Add dimension identifiers
      registry["dimensions"] = {}
      dimensions.each_with_index do |dimension, index|
        next unless dimension.respond_to?(:identifiers)

        dimension.identifiers.each do |identifier|
          next unless identifier.id && identifier.type

          composite_key = "#{identifier.type}:#{identifier.id}"
          registry["dimensions"][composite_key] = "index:#{index}"
          registry["dimensions"][identifier.id] = "index:#{index}"
        end

        # Also track dimensions by short name
        if dimension.respond_to?(:short) && dimension.short
          registry["dimensions_short"] ||= {}
          registry["dimensions_short"][dimension.short] = "index:#{index}"
        end
      end

      # Add quantity identifiers
      registry["quantities"] = {}
      quantities.each_with_index do |quantity, index|
        next unless quantity.respond_to?(:identifiers)

        quantity.identifiers.each do |identifier|
          next unless identifier.id && identifier.type

          composite_key = "#{identifier.type}:#{identifier.id}"
          registry["quantities"][composite_key] = "index:#{index}"
          registry["quantities"][identifier.id] = "index:#{index}"
        end
      end

      # Add prefix identifiers
      registry["prefixes"] = {}
      prefixes.each_with_index do |prefix, index|
        next unless prefix.respond_to?(:identifiers)

        prefix.identifiers.each do |identifier|
          next unless identifier.id && identifier.type

          composite_key = "#{identifier.type}:#{identifier.id}"
          registry["prefixes"][composite_key] = "index:#{index}"
          registry["prefixes"][identifier.id] = "index:#{index}"
        end
      end

      # Add unit system identifiers
      registry["unit_systems"] = {}
      unit_systems.each_with_index do |unit_system, index|
        next unless unit_system.respond_to?(:identifiers)

        unit_system.identifiers.each do |identifier|
          next unless identifier.id && identifier.type

          composite_key = "#{identifier.type}:#{identifier.id}"
          registry["unit_systems"][composite_key] = "index:#{index}"
          registry["unit_systems"][identifier.id] = "index:#{index}"
        end

        # Also track unit systems by short name
        if unit_system.respond_to?(:short) && unit_system.short
          registry["unit_systems_short"] ||= {}
          registry["unit_systems_short"][unit_system.short] = "index:#{index}"
        end
      end

      registry
    end

    def check_dimension_references(registry, invalid_refs)
      dimensions.each_with_index do |dimension, index|
        next unless dimension.respond_to?(:dimension_reference) && dimension.dimension_reference

        ref_id = dimension.dimension_reference
        ref_type = "dimensions"
        ref_path = "dimensions:index:#{index}:dimension_reference"

        validate_reference(ref_id, ref_type, ref_path, registry, invalid_refs,
                           "dimensions")
      end
    end

    def check_unit_system_references(registry, invalid_refs)
      units.each_with_index do |unit, index|
        next unless unit.respond_to?(:unit_system_reference) && unit.unit_system_reference

        unit.unit_system_reference.each_with_index do |ref_id, idx|
          ref_type = "unit_systems"
          ref_path = "units:index:#{index}:unit_system_reference[#{idx}]"

          validate_reference(ref_id, ref_type, ref_path, registry,
                             invalid_refs, "units")
        end
      end
    end

    def check_quantity_references(registry, invalid_refs)
      units.each_with_index do |unit, index|
        next unless unit.respond_to?(:quantity_references) && unit.quantity_references

        unit.quantity_references.each_with_index do |ref_id, idx|
          ref_type = "quantities"
          ref_path = "units:index:#{index}:quantity_references[#{idx}]"

          validate_reference(ref_id, ref_type, ref_path, registry,
                             invalid_refs, "units")
        end
      end
    end

    def check_root_unit_references(registry, invalid_refs)
      units.each_with_index do |unit, index|
        next unless unit.respond_to?(:root_units) && unit.root_units

        unit.root_units.each_with_index do |root_unit, idx|
          next unless root_unit.respond_to?(:unit_reference) && root_unit.unit_reference

          # Check unit reference
          ref_id = root_unit.unit_reference
          ref_type = "units"
          ref_path = "units:index:#{index}:root_units.#{idx}.unit_reference"

          validate_reference(ref_id, ref_type, ref_path, registry,
                             invalid_refs, "units")

          # Check prefix reference if present
          next unless root_unit.respond_to?(:prefix_reference) && root_unit.prefix_reference

          ref_id = root_unit.prefix_reference
          ref_type = "prefixes"
          ref_path = "units:index:#{index}:root_units.#{idx}.prefix_reference"

          validate_reference(ref_id, ref_type, ref_path, registry,
                             invalid_refs, "units")
        end
      end
    end

    def validate_reference(ref_id, ref_type, ref_path, registry, invalid_refs, file_type)
      # Handle references that are objects with id and type (could be a hash or an object)
      if ref_id.respond_to?(:id) && ref_id.respond_to?(:type)
        id = ref_id.id
        type = ref_id.type
        composite_key = "#{type}:#{id}"

        # Try multiple lookup strategies
        valid = false

        # 1. Try exact composite key match
        valid = true if registry.key?(ref_type) && registry[ref_type].key?(composite_key)

        # 2. Try just ID match if composite didn't work
        valid = true if !valid && registry.key?(ref_type) && registry[ref_type].key?(id)

        # 3. Try alternate ID formats for unit systems (e.g., SI_base vs si-base)
        if !valid && type == "unitsml" && ref_type == "unit_systems" && registry.key?(ref_type) && (
            registry[ref_type].keys.any? { |k| k.end_with?(":#{id}") } ||
            registry[ref_type].keys.any? do |k|
              k.end_with?(":SI_#{id.sub('si-', '')}")
            end ||
            registry[ref_type].keys.any? do |k|
              k.end_with?(":non-SI_#{id.sub('nonsi-', '')}")
            end
          )
          # Special handling for unit_systems between unitsml and nist types
          valid = true
        end

        unless valid
          invalid_refs[file_type] ||= {}
          invalid_refs[file_type][ref_path] =
            { id: id, type: type, ref_type: ref_type }
        end
      # Handle references that are objects with id and type in a hash
      elsif ref_id.is_a?(Hash) && ref_id.key?("id") && ref_id.key?("type")
        id = ref_id["id"]
        type = ref_id["type"]
        composite_key = "#{type}:#{id}"

        # Try multiple lookup strategies
        valid = false

        # 1. Try exact composite key match
        valid = true if registry.key?(ref_type) && registry[ref_type].key?(composite_key)

        # 2. Try just ID match if composite didn't work
        valid = true if !valid && registry.key?(ref_type) && registry[ref_type].key?(id)

        # 3. Try alternate ID formats for unit systems (e.g., SI_base vs si-base)
        if !valid && type == "unitsml" && ref_type == "unit_systems" && registry.key?(ref_type) && (
            registry[ref_type].keys.any? { |k| k.end_with?(":#{id}") } ||
            registry[ref_type].keys.any? do |k|
              k.end_with?(":SI_#{id.sub('si-', '')}")
            end ||
            registry[ref_type].keys.any? do |k|
              k.end_with?(":non-SI_#{id.sub('nonsi-', '')}")
            end
          )
          # Special handling for unit_systems between unitsml and nist types
          valid = true
        end

        unless valid
          invalid_refs[file_type] ||= {}
          invalid_refs[file_type][ref_path] =
            { id: id, type: type, ref_type: ref_type }
        end
      else
        # Handle plain string references (legacy format)
        valid = registry.key?(ref_type) && registry[ref_type].key?(ref_id)

        unless valid
          invalid_refs[file_type] ||= {}
          invalid_refs[file_type][ref_path] = { id: ref_id, type: ref_type }
        end
      end
    end
  end

  Config.register_model(Database, id: :database)
end
