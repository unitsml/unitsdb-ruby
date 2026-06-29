# frozen_string_literal: true

module Unitsdb
  module Commands
    module CheckSi
      # Matcher for SI digital-framework entities and UnitsDB entities.
      # All iteration is typed — entities expose `identifiers`, `names`,
      # `short`, `references`, and (for units/prefixes) `symbols` as
      # declared Lutaml attributes, so we read them directly.
      module SiMatcher
        SI_AUTHORITY = "si-digital-framework"
        SYMBOL_ENTITY_TYPES = %w[units prefixes].freeze

        class << self
          attr_accessor :match_details
        end
        self.match_details = {}

        module_function

        # Match TTL entities to database entities (from_si direction)
        def match_ttl_to_db(entity_type, ttl_entities, db_entities)
          matches = []
          missing_matches = []
          matched_ttl_uris = []
          processed_pairs = {}
          entity_matches = {}

          db_entities.each do |entity|
            references = entity.references || []
            references.each do |ref|
              next unless ref.authority == SI_AUTHORITY

              matched_ttl_uris << ref.uri
              ttl_entity = ttl_entities.find { |e| e[:uri] == ref.uri }
              next unless ttl_entity

              matches << {
                entity_id: entity.short,
                entity_name: format_entity_name(entity),
                si_uri: ttl_entity[:uri],
                si_name: ttl_entity[:name],
                si_label: ttl_entity[:label],
                si_alt_label: ttl_entity[:alt_label],
                si_symbol: ttl_entity[:symbol],
                entity: entity,
              }
            end
          end

          ttl_entities.each do |ttl_entity|
            next if matched_ttl_uris.include?(ttl_entity[:uri])

            matching_entities = find_matching_entities(entity_type, ttl_entity, db_entities)
            next if matching_entities.empty?

            matched_ttl_uris << ttl_entity[:uri]

            matching_entities.each do |entity|
              entity_id = entity.short
              pair_key = "#{entity_id}:#{ttl_entity[:uri]}"
              next if processed_pairs[pair_key]

              processed_pairs[pair_key] = true

              match_result = match_entity_names?(entity_type, entity, ttl_entity)
              next unless match_result[:match]

              match_details[pair_key] = match_result

              has_reference = (entity.references || []).any? do |ref|
                ref.uri == ttl_entity[:uri] && ref.authority == SI_AUTHORITY
              end

              match_data = {
                entity_id: entity_id,
                entity_name: format_entity_name(entity),
                si_uri: ttl_entity[:uri],
                si_name: ttl_entity[:name],
                si_label: ttl_entity[:label],
                si_alt_label: ttl_entity[:alt_label],
                si_symbol: ttl_entity[:symbol],
                entity: entity,
                match_type: match_result[:match_type],
                match_details: match_result,
                match_types: { ttl_entity[:uri] => match_result[:match_type] },
              }

              if has_reference
                matches << match_data
              else
                entity_matches[entity_id] ||= []
                entity_matches[entity_id] << {
                  uri: ttl_entity[:uri],
                  name: ttl_entity[:name],
                  label: ttl_entity[:label],
                }
                missing_matches << match_data unless missing_matches.any? { |m| m[:entity_id] == entity_id }
              end
            end
          end

          missing_matches.each do |match|
            si_matches = entity_matches[match[:entity_id]]
            next unless si_matches && si_matches.size > 1

            match[:multiple_si] = si_matches
          end

          unmatched_ttl = ttl_entities.reject do |entity|
            matched_ttl_uris.include?(entity[:uri]) ||
              entity[:uri].end_with?("/units/") ||
              entity[:uri].end_with?("/quantities/") ||
              entity[:uri].end_with?("/prefixes/")
          end

          [matches, missing_matches, unmatched_ttl]
        end

        # Match database entities to TTL entities (to_si direction)
        def match_db_to_ttl(entity_type, ttl_entities, db_entities)
          matches = []
          missing_refs = []
          matched_db_ids = []
          processed_db_ids = {}

          nist_id_to_display = build_nist_id_to_display(entity_type, db_entities)

          db_entities.each do |db_entity|
            entity_id = find_entity_id(db_entity)
            display_id = nist_id_to_display[entity_id] || entity_id

            next if processed_db_ids[entity_id]

            processed_db_ids[entity_id] = true

            has_reference = false
            (db_entity.references || []).each do |ref|
              next unless ref.authority == SI_AUTHORITY

              has_reference = true
              ttl_entity = ttl_entities.find { |e| e[:uri] == ref.uri }
              matches << {
                entity_id: display_id,
                db_entity: db_entity,
                ttl_uri: ref.uri,
                ttl_entity: ttl_entity,
              }
            end

            if has_reference
              matched_db_ids << entity_id
              next
            end

            matching_ttl = []
            match_types = {}

            ttl_entities.each do |ttl_entity|
              match_result = match_entity_names?(entity_type, db_entity, ttl_entity)
              next unless match_result[:match]

              matching_ttl << ttl_entity
              match_types[ttl_entity[:uri]] = match_result[:match_type]
              match_details["#{entity_id}:#{ttl_entity[:uri]}"] = match_result
            end

            next if matching_ttl.empty?

            matched_db_ids << entity_id
            missing_refs << {
              entity_id: display_id,
              db_entity: db_entity,
              ttl_entities: matching_ttl,
              match_types: match_types,
            }
          end

          unmatched_db = db_entities.reject do |entity|
            matched_db_ids.include?(find_entity_id(entity))
          end

          [matches, missing_refs, unmatched_db]
        end

        # UnitsDB top-level entities are identified by their first
        # Identifier's id; if none is present, fall back to short.
        def find_entity_id(entity)
          identifier = entity.identifiers.first
          return identifier.id if identifier&.id

          entity.short
        end

        # First localized name (LocalizedString instance) or nil.
        def format_entity_name(entity)
          entity.names.first
        end

        def find_matching_entities(entity_type, ttl_entity, db_entities)
          finder = MATCHERS[entity_type]
          return [] unless finder

          finder.call(ttl_entity, db_entities)
        end

        # ---- Per-entity-type matchers (open for extension: add to
        # MATCHERS to support a new type) ----

        def find_matching_units(ttl_unit, units)
          units.select do |unit|
            short_matches?(unit.short, ttl_unit) ||
              name_matches?(unit.names, ttl_unit) ||
              symbol_matches?(unit.symbols, ttl_unit)
          end.uniq
        end

        def find_matching_quantities(ttl_quantity, quantities)
          quantities.select do |quantity|
            short_matches_any?(quantity.short, ttl_quantity, %i[name label alt_label]) ||
              name_matches_any?(quantity.names, ttl_quantity, %i[name label alt_label])
          end.uniq
        end

        def find_matching_prefixes(ttl_prefix, prefixes)
          prefixes.select do |prefix|
            short_matches?(prefix.short, ttl_prefix) ||
              name_matches?(prefix.names, ttl_prefix) ||
              prefix_symbol_matches?(prefix.symbols, ttl_prefix)
          end.uniq
        end

        MATCHERS = {
          "units" => method(:find_matching_units),
          "quantities" => method(:find_matching_quantities),
          "prefixes" => method(:find_matching_prefixes),
        }.freeze

        # ---- Generic match primitives ----

        def short_matches?(short, ttl_entity)
          target = ttl_entity[:name]&.downcase
          target_label = ttl_entity[:label]&.downcase
          short && [target, target_label].include?(short.downcase)
        end

        def short_matches_any?(short, ttl_entity, keys)
          targets = keys.map { |k| ttl_entity[k]&.downcase }
          short && targets.include?(short.downcase)
        end

        def name_matches?(names, ttl_entity)
          targets = [ttl_entity[:name]&.downcase, ttl_entity[:label]&.downcase].compact
          names.any? { |n| targets.include?(n.value&.downcase) }
        end

        def name_matches_any?(names, ttl_entity, keys)
          targets = keys.filter_map { |k| ttl_entity[k]&.downcase }
          names.any? { |n| targets.include?(n.value&.downcase) }
        end

        def symbol_matches?(symbols, ttl_entity)
          ttl_symbol = ttl_entity[:symbol]
          return false unless ttl_symbol

          needle = ttl_symbol.downcase
          symbols.any? { |s| s.ascii.to_s.downcase == needle }
        end

        # Prefixes in 2.0 carry a `symbols` collection, just like Units.
        alias prefix_symbol_matches? symbol_matches?

        # ---- Detailed match (returns a hash with match metadata) ----

        def match_entity_names?(entity_type, db_entity, ttl_entity)
          matcher = DetailedMatcher.new(db_entity, ttl_entity, entity_type)
          matcher.call
        end

        # Encapsulates the per-entity detailed match strategies.
        class DetailedMatcher
          def initialize(db_entity, ttl_entity, entity_type)
            @db_entity = db_entity
            @ttl = ttl_entity
            @entity_type = entity_type
          end

          def call
            short_to_name || short_to_label || name_to_name ||
              name_to_label || name_to_alt_label || sidereal_demotion ||
              symbol_potential || NO_MATCH
          end

          NO_MATCH = { match: false }.freeze

          private

          def short_to_name
            return unless @db_entity.short&.downcase == @ttl[:name]&.downcase

            exact_match("short_to_name",
                        "UnitsDB short '#{@db_entity.short}' matches SI name '#{@ttl[:name]}'")
          end

          def short_to_label
            return unless @db_entity.short && @ttl[:label] &&
              @db_entity.short.downcase == @ttl[:label].downcase

            exact_match("short_to_label",
                        "UnitsDB short '#{@db_entity.short}' matches SI label '#{@ttl[:label]}'")
          end

          def name_to_name
            db_name = find_name_match(@ttl[:name])
            return unless db_name

            exact_match("name_to_name",
                        "UnitsDB name '#{db_name}' matches SI name '#{@ttl[:name]}'")
          end

          def name_to_label
            return unless @ttl[:label]

            db_name = find_name_match(@ttl[:label])
            return unless db_name

            exact_match("name_to_label",
                        "UnitsDB name '#{db_name}' matches SI label '#{@ttl[:label]}'")
          end

          def name_to_alt_label
            return unless @ttl[:alt_label]

            db_name = find_name_match(@ttl[:alt_label])
            return unless db_name

            exact_match("name_to_alt_label",
                        "UnitsDB name '#{db_name}' matches SI alt_label '#{@ttl[:alt_label]}'")
          end

          # A `sidereal_*` short counts as a partial match unless the
          # TTL name/label acknowledges the sidereal form.
          def sidereal_demotion
            prior = short_to_name || short_to_label
            return unless prior && prior[:exact]
            return unless @db_entity.short&.include?("sidereal_")
            return if @ttl[:name]&.include?("sidereal") || @ttl[:label]&.include?("sidereal")

            potential_match("partial_match",
                            "UnitsDB '#{@db_entity.short}' partially matches SI '#{@ttl[:name]}'")
          end

          def symbol_potential
            return unless SYMBOL_ENTITY_TYPES.include?(@entity_type)
            return unless @ttl[:symbol]

            needle = @ttl[:symbol].downcase
            match = @db_entity.symbols.find { |s| s.ascii.to_s.downcase == needle }
            return unless match

            potential_match("symbol_match",
                            "UnitsDB symbol '#{match.ascii}' matches SI symbol '#{@ttl[:symbol]}'")
          end

          def find_name_match(ttl_value)
            return unless ttl_value

            needle = ttl_value.downcase
            @db_entity.names.find { |n| n.value&.downcase == needle }
          end

          def exact_match(desc, details)
            {
              match: true,
              exact: true,
              match_type: "Exact match",
              match_desc: desc,
              details: details,
            }
          end

          def potential_match(desc, details)
            {
              match: true,
              exact: false,
              match_type: "Potential match",
              match_desc: desc,
              details: details,
            }
          end
        end

        private_constant :DetailedMatcher, :MATCHERS
      end
    end
  end
end
