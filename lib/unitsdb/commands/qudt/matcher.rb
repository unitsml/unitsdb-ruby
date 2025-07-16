# frozen_string_literal: true

module Unitsdb
  module Commands
    module Qudt
      # Matcher for QUDT and UnitsDB entities
      module Matcher
        module_function

        # Match QUDT entities to UnitsDB entities (QUDT → UnitsDB)
        def match_qudt_to_db(entity_type, qudt_entities, db_entities)
          puts "Matching QUDT #{entity_type} to UnitsDB #{entity_type}..."

          # Initialize result arrays
          matches = []
          missing_matches = []
          unmatched_qudt = []

          # Process each QUDT entity
          qudt_entities.each do |qudt_entity|
            match_data = find_db_match_for_qudt(qudt_entity, db_entities, entity_type)

            if match_data[:match]
              matches << { qudt_entity: qudt_entity, db_entity: match_data[:match] }
            elsif match_data[:potential_match]
              missing_matches << { qudt_entity: qudt_entity, db_entity: match_data[:potential_match] }
            else
              unmatched_qudt << qudt_entity
            end
          end

          [matches, missing_matches, unmatched_qudt]
        end

        # Match UnitsDB entities to QUDT entities (UnitsDB → QUDT)
        def match_db_to_qudt(entity_type, qudt_entities, db_entities)
          puts "Matching UnitsDB #{entity_type} to QUDT #{entity_type}..."

          # Initialize result arrays
          matches = []
          missing_refs = []
          unmatched_db = []

          # Process each UnitsDB entity
          db_entities.each do |db_entity|
            # Skip entities that already have QUDT references
            if has_qudt_reference?(db_entity)
              matches << { db_entity: db_entity, qudt_entity: find_referenced_qudt_entity(db_entity, qudt_entities) }
              next
            end

            match_data = find_qudt_match_for_db(db_entity, qudt_entities, entity_type)

            if match_data[:match]
              missing_refs << { db_entity: db_entity, qudt_entity: match_data[:match] }
            else
              unmatched_db << db_entity
            end
          end

          [matches, missing_refs, unmatched_db]
        end

        # Check if a UnitsDB entity already has a QUDT reference
        def has_qudt_reference?(entity)
          return false unless entity.respond_to?(:references) && entity.references

          entity.references.any? { |ref| ref.authority == "qudt" }
        end

        # Find the referenced QUDT entity based on the reference URI
        def find_referenced_qudt_entity(db_entity, qudt_entities)
          return nil unless db_entity.respond_to?(:references) && db_entity.references

          qudt_ref = db_entity.references.find { |ref| ref.authority == "qudt" }
          return nil unless qudt_ref

          ref_uri = qudt_ref.uri
          qudt_entities.find { |qudt_entity| qudt_entity.uri == ref_uri }
        end

        # Get the ID of a UnitsDB entity
        def get_entity_id(entity)
          entity.respond_to?(:id) ? entity.id : nil
        end

        # Find a matching UnitsDB entity for a QUDT entity
        def find_db_match_for_qudt(qudt_entity, db_entities, entity_type)
          result = { match: nil, potential_match: nil }

          # Different matching logic based on entity type
          case entity_type
          when "units"
            result = match_unit_qudt_to_db(qudt_entity, db_entities)
          when "quantities"
            result = match_quantity_qudt_to_db(qudt_entity, db_entities)
          when "dimensions"
            result = match_dimension_qudt_to_db(qudt_entity, db_entities)
          when "unit_systems"
            result = match_unit_system_qudt_to_db(qudt_entity, db_entities)
          when "prefixes"
            result = match_prefix_qudt_to_db(qudt_entity, db_entities)
          end

          result
        end

        # Find a matching QUDT entity for a UnitsDB entity
        def find_qudt_match_for_db(db_entity, qudt_entities, entity_type)
          result = { match: nil }

          # Different matching logic based on entity type
          case entity_type
          when "units"
            result = match_unit_db_to_qudt(db_entity, qudt_entities)
          when "quantities"
            result = match_quantity_db_to_qudt(db_entity, qudt_entities)
          when "dimensions"
            result = match_dimension_db_to_qudt(db_entity, qudt_entities)
          when "unit_systems"
            result = match_unit_system_db_to_qudt(db_entity, qudt_entities)
          when "prefixes"
            result = match_prefix_db_to_qudt(db_entity, qudt_entities)
          end

          result
        end

        # Match QUDT unit to UnitsDB unit
        def match_unit_qudt_to_db(qudt_unit, db_units)
          result = { match: nil, potential_match: nil }

          # PRIORITY 0: Try SI exact match first (highest confidence)
          if qudt_unit.si_exact_match
            si_match = find_unit_by_si_reference(qudt_unit.si_exact_match, db_units)
            if si_match
              result[:match] = si_match
              return result
            end
          end

          # PRIORITY 1: Try symbol match (most reliable)
          if qudt_unit.symbol
            symbol_match = db_units.find do |db_unit|
              db_unit.symbols&.any? do |symbol|
                symbol.ascii&.downcase == qudt_unit.symbol.downcase ||
                  symbol.unicode&.downcase == qudt_unit.symbol.downcase
              end
            end

            if symbol_match
              result[:match] = symbol_match
              return result
            end
          end

          # PRIORITY 2: Try exact label match
          if qudt_unit.label
            label_match = db_units.find do |db_unit|
              db_unit.names&.any? do |name_obj|
                name_obj.value.downcase == qudt_unit.label.downcase
              end
            end

            if label_match
              result[:match] = label_match
              return result
            end
          end

          # PRIORITY 3: Try normalized name matching (remove common variations)
          if qudt_unit.label
            normalized_match = db_units.find do |db_unit|
              db_unit.names&.any? do |name_obj|
                normalize_name(qudt_unit.label) == normalize_name(name_obj.value)
              end
            end

            if normalized_match
              result[:match] = normalized_match
              return result
            end
          end

          # PRIORITY 4: Try partial name match for potential matches (be conservative)
          if qudt_unit.label && qudt_unit.label.length > 3
            partial_matches = db_units.select do |db_unit|
              db_unit.names&.any? do |name_obj|
                name_obj.value.downcase.include?(qudt_unit.label.downcase) ||
                  qudt_unit.label.downcase.include?(name_obj.value.downcase)
              end
            end

            result[:potential_match] = partial_matches.first if partial_matches.any?
          end

          result
        end

        # Match UnitsDB unit to QUDT unit
        def match_unit_db_to_qudt(db_unit, qudt_units)
          result = { match: nil }

          # PRIORITY 1: Try symbol match first (most reliable)
          if db_unit.symbols && !db_unit.symbols.empty?
            symbol_match = qudt_units.find do |qudt_unit|
              qudt_unit.symbol && db_unit.symbols.any? do |symbol|
                qudt_unit.symbol.downcase == symbol.ascii&.downcase ||
                  qudt_unit.symbol.downcase == symbol.unicode&.downcase
              end
            end

            if symbol_match
              result[:match] = symbol_match
              return result
            end
          end

          # PRIORITY 2: Try exact name match
          if db_unit.names && !db_unit.names.empty?
            db_unit_names = db_unit.names.map { |name_obj| name_obj.value.downcase }

            name_match = qudt_units.find do |qudt_unit|
              qudt_unit.label && db_unit_names.include?(qudt_unit.label.downcase)
            end

            if name_match
              result[:match] = name_match
              return result
            end

            # PRIORITY 3: Try normalized name matching
            normalized_match = qudt_units.find do |qudt_unit|
              qudt_unit.label && db_unit_names.any? do |db_name|
                normalize_name(qudt_unit.label) == normalize_name(db_name)
              end
            end

            result[:match] = normalized_match if normalized_match
          end

          result
        end

        # Match QUDT quantity kind to UnitsDB quantity
        def match_quantity_qudt_to_db(qudt_quantity, db_quantities)
          result = { match: nil, potential_match: nil }

          # Try exact label match first
          if qudt_quantity.label
            label_match = db_quantities.find do |db_quantity|
              db_quantity.names&.any? do |name_obj|
                name_obj.value.downcase == qudt_quantity.label.downcase
              end
            end

            if label_match
              result[:match] = label_match
              return result
            end
          end

          # Try symbol match if available
          if qudt_quantity.symbol
            symbol_match = db_quantities.find do |db_quantity|
              db_quantity.names&.any? do |name_obj|
                name_obj.value.downcase == qudt_quantity.symbol.downcase
              end
            end

            if symbol_match
              result[:match] = symbol_match
              return result
            end
          end

          # Try normalized name matching (remove common variations)
          if qudt_quantity.label
            normalized_match = db_quantities.find do |db_quantity|
              db_quantity.names&.any? do |name_obj|
                normalize_name(qudt_quantity.label) == normalize_name(name_obj.value)
              end
            end

            if normalized_match
              result[:match] = normalized_match
              return result
            end
          end

          # Try partial name match for potential matches
          if qudt_quantity.label
            partial_matches = db_quantities.select do |db_quantity|
              db_quantity.names&.any? do |name_obj|
                name_obj.value.downcase.include?(qudt_quantity.label.downcase) ||
                  qudt_quantity.label.downcase.include?(name_obj.value.downcase)
              end
            end

            result[:potential_match] = partial_matches.first if partial_matches.any?
          end

          result
        end

        # Match UnitsDB quantity to QUDT quantity kind
        def match_quantity_db_to_qudt(db_quantity, qudt_quantities)
          result = { match: nil }

          # Try name match first
          if db_quantity.names && !db_quantity.names.empty?
            db_quantity_names = db_quantity.names.map { |name_obj| name_obj.value.downcase }

            name_match = qudt_quantities.find do |qudt_quantity|
              qudt_quantity.label && db_quantity_names.include?(qudt_quantity.label.downcase)
            end

            if name_match
              result[:match] = name_match
              return result
            end

            # Try normalized name matching
            normalized_match = qudt_quantities.find do |qudt_quantity|
              qudt_quantity.label && db_quantity_names.any? do |db_name|
                normalize_name(qudt_quantity.label) == normalize_name(db_name)
              end
            end

            result[:match] = normalized_match if normalized_match
          end

          result
        end

        # Match QUDT dimension vector to UnitsDB dimension
        def match_dimension_qudt_to_db(qudt_dimension, db_dimensions)
          result = { match: nil, potential_match: nil }

          # Try dimensional analysis match first (most reliable for dimension vectors)
          dimensional_match = db_dimensions.find do |db_dimension|
            dimensions_match?(qudt_dimension, db_dimension)
          end

          if dimensional_match
            result[:match] = dimensional_match
            return result
          end

          # Try exact label match as fallback
          if qudt_dimension.label
            label_match = db_dimensions.find do |db_dimension|
              db_dimension.names&.any? do |name_obj|
                name_obj.value.downcase == qudt_dimension.label.downcase
              end
            end

            if label_match
              result[:potential_match] = label_match
            end
          end

          result
        end

        # Match UnitsDB dimension to QUDT dimension vector
        def match_dimension_db_to_qudt(db_dimension, qudt_dimensions)
          result = { match: nil }

          # Try dimensional analysis match first (most reliable)
          dimensional_match = qudt_dimensions.find do |qudt_dimension|
            dimensions_match?(qudt_dimension, db_dimension)
          end

          if dimensional_match
            result[:match] = dimensional_match
            return result
          end

          # Try name match as fallback
          if db_dimension.names && !db_dimension.names.empty?
            db_dimension_names = db_dimension.names.map { |name_obj| name_obj.value.downcase }

            name_match = qudt_dimensions.find do |qudt_dimension|
              qudt_dimension.label && db_dimension_names.include?(qudt_dimension.label.downcase)
            end

            result[:match] = name_match if name_match
          end

          result
        end

        # Match QUDT system of units to UnitsDB unit system
        def match_unit_system_qudt_to_db(qudt_system, db_unit_systems)
          result = { match: nil, potential_match: nil }

          # Try exact label match first
          if qudt_system.label
            label_match = db_unit_systems.find do |db_system|
              db_system.names&.any? do |name_obj|
                name_obj.value.downcase == qudt_system.label.downcase
              end
            end

            if label_match
              result[:match] = label_match
              return result
            end
          end

          # Try abbreviation match
          if qudt_system.abbreviation
            abbrev_match = db_unit_systems.find do |db_system|
              db_system.names&.any? do |name_obj|
                name_obj.value.downcase == qudt_system.abbreviation.downcase
              end
            end

            if abbrev_match
              result[:match] = abbrev_match
              return result
            end
          end

          # Try smart matching for known systems
          if qudt_system.abbreviation
            smart_match = db_unit_systems.find do |db_system|
              db_system.names&.any? do |name_obj|
                case qudt_system.abbreviation.downcase
                when "si"
                  # Match SI abbreviation to any system containing "si"
                  name_obj.value.downcase.include?("si")
                when "cgs"
                  # Match CGS abbreviation to any system containing "cgs"
                  name_obj.value.downcase.include?("cgs")
                when "imperial"
                  # Match Imperial to any system containing "imperial"
                  name_obj.value.downcase.include?("imperial")
                when "us customary"
                  # Match US Customary to any system containing "us" or "customary"
                  name_obj.value.downcase.include?("us") || name_obj.value.downcase.include?("customary")
                else
                  false
                end
              end
            end

            if smart_match
              result[:match] = smart_match
              return result
            end
          end

          result
        end

        # Match UnitsDB unit system to QUDT system of units
        def match_unit_system_db_to_qudt(db_system, qudt_systems)
          result = { match: nil }

          # Try name match first
          if db_system.names && !db_system.names.empty?
            db_system_names = db_system.names.map { |name_obj| name_obj.value.downcase }

            name_match = qudt_systems.find do |qudt_system|
              (qudt_system.label && db_system_names.include?(qudt_system.label.downcase)) ||
                (qudt_system.abbreviation && db_system_names.include?(qudt_system.abbreviation.downcase))
            end

            if name_match
              result[:match] = name_match
              return result
            end

            # Try smart matching for known systems
            smart_match = qudt_systems.find do |qudt_system|
              db_system_names.any? do |db_name|
                case
                when db_name.include?("si") && qudt_system.abbreviation&.downcase == "si"
                  true
                when db_name.include?("cgs") && qudt_system.abbreviation&.downcase == "cgs"
                  true
                when db_name.include?("imperial") && qudt_system.abbreviation&.downcase == "imperial"
                  true
                when (db_name.include?("us") || db_name.include?("customary")) && qudt_system.abbreviation&.downcase == "us customary"
                  true
                else
                  false
                end
              end
            end

            result[:match] = smart_match if smart_match
          end

          result
        end

        # Check if QUDT dimension vector matches UnitsDB dimension
        def dimensions_match?(qudt_dimension, db_dimension)
          return false unless qudt_dimension.respond_to?(:dimension_exponent_for_length)

          # Map QUDT dimension exponents to UnitsDB dimension structure
          qudt_exponents = {
            length: qudt_dimension.dimension_exponent_for_length || 0,
            mass: qudt_dimension.dimension_exponent_for_mass || 0,
            time: qudt_dimension.dimension_exponent_for_time || 0,
            electric_current: qudt_dimension.dimension_exponent_for_electric_current || 0,
            thermodynamic_temperature: qudt_dimension.dimension_exponent_for_thermodynamic_temperature || 0,
            amount_of_substance: qudt_dimension.dimension_exponent_for_amount_of_substance || 0,
            luminous_intensity: qudt_dimension.dimension_exponent_for_luminous_intensity || 0
          }

          # Get UnitsDB dimension exponents from direct properties
          db_exponents = {
            length: get_dimension_power(db_dimension, :length),
            mass: get_dimension_power(db_dimension, :mass),
            time: get_dimension_power(db_dimension, :time),
            electric_current: get_dimension_power(db_dimension, :electric_current),
            thermodynamic_temperature: get_dimension_power(db_dimension, :thermodynamic_temperature),
            amount_of_substance: get_dimension_power(db_dimension, :amount_of_substance),
            luminous_intensity: get_dimension_power(db_dimension, :luminous_intensity)
          }

          # Compare all dimension exponents
          qudt_exponents == db_exponents
        end

        # Get dimension power from UnitsDB dimension entity
        def get_dimension_power(db_dimension, dimension_type)
          return 0 unless db_dimension.respond_to?(dimension_type)

          dimension_property = db_dimension.send(dimension_type)
          return 0 unless dimension_property && dimension_property.respond_to?(:power)

          dimension_property.power || 0
        end

        # Normalize names by removing common variations and punctuation
        def normalize_name(name)
          return "" unless name

          name.downcase
              .gsub(/\s+/, " ")           # normalize whitespace
              .gsub(/[-_]/, " ")          # convert dashes/underscores to spaces
              .gsub(/[()\\[\\]]/, "")     # remove parentheses and brackets
              .gsub(/\bof\b/, "")         # remove "of"
              .gsub(/\bper\b/, "/")       # convert "per" to "/"
              .strip
        end

        # Find a UnitsDB unit that has an SI reference matching the given SI URI
        def find_unit_by_si_reference(si_uri, db_units)
          return nil unless si_uri

          # Extract the SI unit identifier from the URI
          # Example: "http://qudt.org/vocab/unit/M" -> "M"
          si_identifier = si_uri.split('/').last

          # Look for a UnitsDB unit that has an SI reference with this identifier
          db_units.find do |db_unit|
            next unless db_unit.respond_to?(:references) && db_unit.references

            db_unit.references.any? do |ref|
              ref.authority == "si" && (
                ref.uri&.end_with?(si_identifier) ||
                ref.uri&.include?(si_identifier)
              )
            end
          end
        end

        # Match QUDT prefix to UnitsDB prefix
        def match_prefix_qudt_to_db(qudt_prefix, db_prefixes)
          result = { match: nil, potential_match: nil }

          # PRIORITY 1: Try UCUM code match first (most reliable for prefixes)
          if qudt_prefix.ucum_code
            ucum_match = db_prefixes.find do |db_prefix|
              db_prefix.respond_to?(:references) && db_prefix.references&.any? do |ref|
                ref.authority == "ucum" && ref.uri&.include?(qudt_prefix.ucum_code)
              end
            end

            if ucum_match
              result[:match] = ucum_match
              return result
            end
          end

          # PRIORITY 2: Try symbol match (very reliable for prefixes)
          if qudt_prefix.symbol
            symbol_match = db_prefixes.find do |db_prefix|
              db_prefix.symbols&.any? do |symbol|
                symbol.ascii&.downcase == qudt_prefix.symbol.downcase ||
                  symbol.unicode&.downcase == qudt_prefix.symbol.downcase
              end
            end

            if symbol_match
              result[:match] = symbol_match
              return result
            end
          end

          # PRIORITY 3: Try exact label match
          if qudt_prefix.label
            label_match = db_prefixes.find do |db_prefix|
              db_prefix.names&.any? do |name_obj|
                name_obj.value.downcase == qudt_prefix.label.downcase
              end
            end

            if label_match
              result[:match] = label_match
              return result
            end
          end

          # PRIORITY 4: Try multiplier match (for prefixes with same scale factor)
          if qudt_prefix.prefix_multiplier
            multiplier_match = db_prefixes.find do |db_prefix|
              db_prefix.respond_to?(:factor) &&
                (db_prefix.factor - qudt_prefix.prefix_multiplier).abs < 1e-10
            end

            if multiplier_match
              result[:match] = multiplier_match
              return result
            end
          end

          # PRIORITY 5: Try normalized name matching
          if qudt_prefix.label
            normalized_match = db_prefixes.find do |db_prefix|
              db_prefix.names&.any? do |name_obj|
                normalize_name(qudt_prefix.label) == normalize_name(name_obj.value)
              end
            end

            if normalized_match
              result[:potential_match] = normalized_match
            end
          end

          result
        end

        # Match UnitsDB prefix to QUDT prefix
        def match_prefix_db_to_qudt(db_prefix, qudt_prefixes)
          result = { match: nil }

          # PRIORITY 1: Try symbol match first (most reliable)
          if db_prefix.symbols && !db_prefix.symbols.empty?
            symbol_match = qudt_prefixes.find do |qudt_prefix|
              qudt_prefix.symbol && db_prefix.symbols.any? do |symbol|
                qudt_prefix.symbol.downcase == symbol.ascii&.downcase ||
                  qudt_prefix.symbol.downcase == symbol.unicode&.downcase
              end
            end

            if symbol_match
              result[:match] = symbol_match
              return result
            end
          end

          # PRIORITY 2: Try exact name match
          if db_prefix.names && !db_prefix.names.empty?
            db_prefix_names = db_prefix.names.map { |name_obj| name_obj.value.downcase }

            name_match = qudt_prefixes.find do |qudt_prefix|
              qudt_prefix.label && db_prefix_names.include?(qudt_prefix.label.downcase)
            end

            if name_match
              result[:match] = name_match
              return result
            end

            # PRIORITY 3: Try normalized name matching
            normalized_match = qudt_prefixes.find do |qudt_prefix|
              qudt_prefix.label && db_prefix_names.any? do |db_name|
                normalize_name(qudt_prefix.label) == normalize_name(db_name)
              end
            end

            if normalized_match
              result[:match] = normalized_match
              return result
            end
          end

          # PRIORITY 4: Try multiplier match (for prefixes with same scale factor)
          if db_prefix.respond_to?(:factor) && db_prefix.factor
            multiplier_match = qudt_prefixes.find do |qudt_prefix|
              qudt_prefix.prefix_multiplier &&
                (qudt_prefix.prefix_multiplier - db_prefix.factor).abs < 1e-10
            end

            result[:match] = multiplier_match if multiplier_match
          end

          result
        end

        # Check if an entity has been manually verified (has a special flag)
        def manually_verified?(entity)
          return false unless entity.respond_to?(:references) && entity.references

          entity.references.any? { |ref| ref.authority == "qudt" && ref.respond_to?(:verified) && ref.verified }
        end
      end
    end
  end
end
