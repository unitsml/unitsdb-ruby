# frozen_string_literal: true

module Unitsdb
  module Commands
    module Ucum
      # Matcher for UCUM and UnitsDB entities
      module Matcher
        module_function

        # Match UCUM entities to UnitsDB entities (UCUM → UnitsDB)
        def match_ucum_to_db(entity_type, ucum_entities, db_entities)
          puts "Matching UCUM #{entity_type} to UnitsDB #{entity_type}..."

          # Initialize result arrays
          matches = []
          missing_matches = []
          unmatched_ucum = []

          # Process each UCUM entity
          ucum_entities.each do |ucum_entity|
            match_data = find_db_match_for_ucum(ucum_entity, db_entities, entity_type)

            if match_data[:match]
              matches << { ucum_entity: ucum_entity, db_entity: match_data[:match] }
            elsif match_data[:potential_match]
              missing_matches << { ucum_entity: ucum_entity, db_entity: match_data[:potential_match] }
            else
              unmatched_ucum << ucum_entity
            end
          end

          [matches, missing_matches, unmatched_ucum]
        end

        # Match UnitsDB entities to UCUM entities (UnitsDB → UCUM)
        def match_db_to_ucum(entity_type, ucum_entities, db_entities)
          puts "Matching UnitsDB #{entity_type} to UCUM #{entity_type}..."

          # Initialize result arrays
          matches = []
          missing_refs = []
          unmatched_db = []

          # Process each UnitsDB entity
          db_entities.send(entity_type).each do |db_entity|
            # Skip entities that already have UCUM references
            if has_ucum_reference?(db_entity)
              matches << { db_entity: db_entity, ucum_entity: find_referenced_ucum_entity(db_entity, ucum_entities) }
              next
            end

            match_data = find_ucum_match_for_db(db_entity, ucum_entities, entity_type)

            if match_data[:match]
              missing_refs << { db_entity: db_entity, ucum_entity: match_data[:match] }
            else
              unmatched_db << db_entity
            end
          end

          [matches, missing_refs, unmatched_db]
        end

        # Check if a UnitsDB entity already has a UCUM reference
        def has_ucum_reference?(entity)
          return false unless entity.respond_to?(:references) && entity.references

          entity.references.any? { |ref| ref.authority == "ucum" }
        end

        # Find the referenced UCUM entity based on the reference URI
        def find_referenced_ucum_entity(db_entity, ucum_entities)
          return nil unless db_entity.respond_to?(:references) && db_entity.references

          ucum_ref = db_entity.references.find { |ref| ref.authority == "ucum" }
          return nil unless ucum_ref

          ref_uri = ucum_ref.uri
          ucum_entities.find { |ucum_entity| ucum_entity.identifier == ref_uri }
        end

        # Get the ID of a UnitsDB entity
        def get_entity_id(entity)
          entity.respond_to?(:id) ? entity.id : nil
        end

        # Find a matching UnitsDB entity for a UCUM entity
        def find_db_match_for_ucum(ucum_entity, db_entities, entity_type)
          result = { match: nil, potential_match: nil }

          # Different matching logic based on entity type
          case entity_type
          when "prefixes"
            result = match_prefix_ucum_to_db(ucum_entity, db_entities)
          when "units"
            result = match_unit_ucum_to_db(ucum_entity, db_entities)
          end

          result
        end

        # Find a matching UCUM entity for a UnitsDB entity
        def find_ucum_match_for_db(db_entity, ucum_entities, entity_type)
          result = { match: nil }

          # Different matching logic based on entity type
          case entity_type
          when "prefixes"
            result = match_prefix_db_to_ucum(db_entity, ucum_entities)
          when "units"
            result = match_unit_db_to_ucum(db_entity, ucum_entities)
          end

          result
        end

        # Match UCUM prefix to UnitsDB prefix
        def match_prefix_ucum_to_db(ucum_prefix, db_prefixes)
          result = { match: nil, potential_match: nil }

          # Try exact name match first
          name_match = db_prefixes.find do |db_prefix|
            db_prefix.names&.any? do |name_obj|
              name_obj.value.downcase == ucum_prefix.name.downcase
            end
          end

          if name_match
            result[:match] = name_match
            return result
          end

          # Try symbol match
          symbol_match = db_prefixes.find do |db_prefix|
            db_prefix.symbols&.any? do |symbol|
              symbol.ascii == ucum_prefix.print_symbol ||
                symbol.unicode == ucum_prefix.print_symbol
            end
          end

          if symbol_match
            result[:match] = symbol_match
            return result
          end

          # Try value match if available (using base^power)
          if ucum_prefix.value&.value
            value_match = db_prefixes.find do |db_prefix|
              if db_prefix.base && db_prefix.power
                calculated_value = db_prefix.base**db_prefix.power
                calculated_value.to_s == ucum_prefix.value.value
              else
                false
              end
            end

            result[:potential_match] = value_match if value_match
          end

          result
        end

        # Match UnitsDB prefix to UCUM prefix
        def match_prefix_db_to_ucum(db_prefix, ucum_prefixes)
          result = { match: nil }

          # Try exact name match first
          if db_prefix.names && !db_prefix.names.empty?
            db_prefix_names = db_prefix.names.map { |name_obj| name_obj.value.downcase }

            name_match = ucum_prefixes.find do |ucum_prefix|
              db_prefix_names.include?(ucum_prefix.name.downcase)
            end

            if name_match
              result[:match] = name_match
              return result
            end
          end

          # Try symbol match
          if db_prefix.symbols && !db_prefix.symbols.empty?
            symbol_match = ucum_prefixes.find do |ucum_prefix|
              db_prefix.symbols.any? do |symbol|
                ucum_prefix.print_symbol == symbol.ascii ||
                  ucum_prefix.print_symbol == symbol.unicode
              end
            end

            result[:match] = symbol_match if symbol_match
          end

          result
        end

        # Match UCUM unit to UnitsDB unit
        def match_unit_ucum_to_db(ucum_unit, db_units)
          result = { match: nil, potential_match: nil }

          # Get UCUM unit name(s)
          ucum_names = case ucum_unit
                       when Unitsdb::UcumBaseUnit
                         [ucum_unit.name]
                       when Unitsdb::UcumUnit
                         ucum_unit.name.is_a?(Array) ? ucum_unit.name : [ucum_unit.name]
                       else
                         []
                       end

          # Try name match
          ucum_names.each do |ucum_name|
            name_match = db_units.find do |db_unit|
              db_unit.names&.any? do |name_obj|
                name_obj.value.downcase == ucum_name.downcase
              end
            end

            if name_match
              result[:match] = name_match
              return result
            end
          end

          # Try symbol match
          symbol_match = db_units.find do |db_unit|
            db_unit.symbols&.any? do |symbol|
              symbol.ascii == ucum_unit.print_symbol ||
                symbol.unicode == ucum_unit.print_symbol
            end
          end

          if symbol_match
            result[:match] = symbol_match
            return result
          end

          # Try property/dimension match for potential matches
          property = case ucum_unit
                     when Unitsdb::UcumBaseUnit
                       ucum_unit.property
                     when Unitsdb::UcumUnit
                       ucum_unit.property
                     end

          if property
            property_matches = db_units.select do |db_unit|
              db_unit.quantity_references&.any? do |qref|
                qref.id&.downcase&.include?(property.downcase)
              end
            end

            result[:potential_match] = property_matches.first if property_matches.any?
          end

          result
        end

        # Match UnitsDB unit to UCUM unit
        def match_unit_db_to_ucum(db_unit, ucum_units)
          result = { match: nil }

          # Try name match first
          if db_unit.names && !db_unit.names.empty?
            db_unit_names = db_unit.names.map { |name_obj| name_obj.value.downcase }

            name_match = ucum_units.find do |ucum_unit|
              case ucum_unit
              when Unitsdb::UcumBaseUnit
                db_unit_names.include?(ucum_unit.name.downcase)
              when Unitsdb::UcumUnit
                ucum_names = ucum_unit.name.is_a?(Array) ? ucum_unit.name : [ucum_unit.name]
                ucum_names.any? { |name| db_unit_names.include?(name.downcase) }
              else
                false
              end
            end

            if name_match
              result[:match] = name_match
              return result
            end
          end

          # Try symbol match
          if db_unit.symbols && !db_unit.symbols.empty?
            symbol_match = ucum_units.find do |ucum_unit|
              db_unit.symbols.any? do |symbol|
                ucum_unit.print_symbol == symbol.ascii ||
                  ucum_unit.print_symbol == symbol.unicode
              end
            end

            result[:match] = symbol_match if symbol_match
          end

          result
        end
      end
    end
  end
end
