# frozen_string_literal: true

module Unitsdb
  module Commands
    module Qudt
      # Formats output for QUDT matching results
      module Formatter
        module_function

        # Print a direction header (UnitsDB → QUDT or QUDT → UnitsDB)
        def print_direction_header(direction)
          puts "\n=== #{direction} ===\n"
        end

        # Display results for QUDT → UnitsDB matching
        def display_qudt_results(entity_type, matches, missing_matches, unmatched_qudt)
          puts "\nResults for #{entity_type.capitalize} (QUDT → UnitsDB):"
          puts "  Matched: #{matches.size}"
          puts "  Missing matches (could be added): #{missing_matches.size}"
          puts "  Unmatched QUDT entities: #{unmatched_qudt.size}"

          return if missing_matches.empty?

          puts "\nPotential additions (QUDT #{entity_type} that could be added to UnitsDB):"
          missing_matches.each do |match|
            qudt_entity = match[:qudt_entity]
            db_entity = match[:db_entity]

            # Get entity IDs and names
            db_id = get_db_entity_id(db_entity)
            db_name = get_db_entity_name(db_entity)
            qudt_name = get_qudt_entity_name(qudt_entity)
            qudt_uri = qudt_entity.uri

            case qudt_entity
            when Unitsdb::QudtUnit
              puts "  - UnitsDB unit '#{db_name}' (#{db_id}) → QUDT unit '#{qudt_name}' (#{qudt_uri})"
            when Unitsdb::QudtQuantityKind
              puts "  - UnitsDB quantity '#{db_name}' (#{db_id}) → QUDT quantity kind '#{qudt_name}' (#{qudt_uri})"
            when Unitsdb::QudtDimensionVector
              puts "  - UnitsDB dimension '#{db_name}' (#{db_id}) → QUDT dimension vector '#{qudt_name}' (#{qudt_uri})"
            when Unitsdb::QudtSystemOfUnits
              puts "  - UnitsDB unit system '#{db_name}' (#{db_id}) → QUDT system of units '#{qudt_name}' (#{qudt_uri})"
            end
          end
        end

        # Display missing QUDT entities analysis
        def display_missing_qudt_entities(entity_type, unmatched_qudt)
          return if unmatched_qudt.empty?

          puts "\n" + "=" * 60
          puts "MISSING QUDT ENTITIES ANALYSIS"
          puts "=" * 60
          puts "\nQUDT #{entity_type.capitalize} that don't exist in UnitsDB (#{unmatched_qudt.size} total):"
          puts "\nThese are QUDT entities that have no corresponding entity in UnitsDB."
          puts "Consider whether any of these should be added to UnitsDB.\n"

          unmatched_qudt.each_with_index do |entity, index|
            puts "\n#{index + 1}. #{format_qudt_entity_details(entity)}"
          end

          puts "\n" + "-" * 60
          puts "RECOMMENDATION: Review these entities to determine if any should be added to UnitsDB."
          puts "Focus on commonly used #{entity_type} that would benefit the UnitsDB community."
          puts "-" * 60
        end

        # Format detailed information about a QUDT entity
        def format_qudt_entity_details(entity)
          case entity
          when Unitsdb::QudtUnit
            details = "UNIT: #{entity.label || 'No label'}"
            details += "\n   URI: #{entity.uri}"
            details += "\n   Symbol: #{entity.symbol}" if entity.symbol
            details += "\n   Description: #{entity.description}" if entity.description
            details += "\n   Quantity Kind: #{entity.has_quantity_kind}" if entity.has_quantity_kind
            details += "\n   Dimension Vector: #{entity.has_dimension_vector}" if entity.has_dimension_vector
            details += "\n   Conversion Multiplier: #{entity.conversion_multiplier}" if entity.conversion_multiplier
            details
          when Unitsdb::QudtQuantityKind
            details = "QUANTITY KIND: #{entity.label || 'No label'}"
            details += "\n   URI: #{entity.uri}"
            details += "\n   Symbol: #{entity.symbol}" if entity.symbol
            details += "\n   Description: #{entity.description}" if entity.description
            details += "\n   Dimension Vector: #{entity.has_dimension_vector}" if entity.has_dimension_vector
            details
          when Unitsdb::QudtDimensionVector
            details = "DIMENSION VECTOR: #{entity.label || 'No label'}"
            details += "\n   URI: #{entity.uri}"
            details += "\n   Description: #{entity.description}" if entity.description
            if entity.respond_to?(:dimension_exponent_for_length)
              exponents = []
              exponents << "L:#{entity.dimension_exponent_for_length}" if entity.dimension_exponent_for_length != 0
              exponents << "M:#{entity.dimension_exponent_for_mass}" if entity.dimension_exponent_for_mass != 0
              exponents << "T:#{entity.dimension_exponent_for_time}" if entity.dimension_exponent_for_time != 0
              exponents << "I:#{entity.dimension_exponent_for_electric_current}" if entity.dimension_exponent_for_electric_current != 0
              exponents << "Θ:#{entity.dimension_exponent_for_thermodynamic_temperature}" if entity.dimension_exponent_for_thermodynamic_temperature != 0
              exponents << "N:#{entity.dimension_exponent_for_amount_of_substance}" if entity.dimension_exponent_for_amount_of_substance != 0
              exponents << "J:#{entity.dimension_exponent_for_luminous_intensity}" if entity.dimension_exponent_for_luminous_intensity != 0
              details += "\n   Exponents: #{exponents.join(', ')}" unless exponents.empty?
            end
            details
          when Unitsdb::QudtSystemOfUnits
            details = "SYSTEM OF UNITS: #{entity.label || 'No label'}"
            details += "\n   URI: #{entity.uri}"
            details += "\n   Abbreviation: #{entity.abbreviation}" if entity.abbreviation
            details += "\n   Description: #{entity.description}" if entity.description
            details
          else
            "UNKNOWN ENTITY TYPE: #{entity.uri}"
          end
        end

        # Display results for UnitsDB → QUDT matching
        def display_db_results(entity_type, matches, missing_refs, unmatched_db)
          puts "\nResults for #{entity_type.capitalize} (UnitsDB → QUDT):"
          puts "  Matched: #{matches.size}"
          puts "  Missing references (could be added): #{missing_refs.size}"
          puts "  Unmatched UnitsDB entities: #{unmatched_db.size}"

          unless unmatched_db.empty?
            puts "\nUnmatched UnitsDB #{entity_type}:"
            unmatched_db.each do |entity|
              id = get_db_entity_id(entity)
              name = get_db_entity_name(entity)
              puts "  - #{name} (#{id})"
            end
          end

          return if missing_refs.empty?

          puts "\nPotential references (QUDT references that could be added to UnitsDB):"
          missing_refs.each do |match|
            qudt_entity = match[:qudt_entity]
            db_entity = match[:db_entity]

            # Get entity IDs and names
            db_id = get_db_entity_id(db_entity)
            db_name = get_db_entity_name(db_entity)
            qudt_name = get_qudt_entity_name(qudt_entity)
            qudt_uri = qudt_entity.uri

            case qudt_entity
            when Unitsdb::QudtUnit
              puts "  - UnitsDB unit '#{db_name}' (#{db_id}) → QUDT unit '#{qudt_name}' (#{qudt_uri})"
            when Unitsdb::QudtQuantityKind
              puts "  - UnitsDB quantity '#{db_name}' (#{db_id}) → QUDT quantity kind '#{qudt_name}' (#{qudt_uri})"
            when Unitsdb::QudtDimensionVector
              puts "  - UnitsDB dimension '#{db_name}' (#{db_id}) → QUDT dimension vector '#{qudt_name}' (#{qudt_uri})"
            when Unitsdb::QudtSystemOfUnits
              puts "  - UnitsDB unit system '#{db_name}' (#{db_id}) → QUDT system of units '#{qudt_name}' (#{qudt_uri})"
            end
          end
        end

        # Helper to get db entity id
        def get_db_entity_id(entity)
          if entity.respond_to?(:identifiers) && entity.identifiers && !entity.identifiers.empty?
            entity.identifiers.first.id
          elsif entity.respond_to?(:id)
            entity.id
          else
            "unknown-id"
          end
        end

        # Helper to get db entity name
        def get_db_entity_name(entity)
          if entity.respond_to?(:names) && entity.names && !entity.names.empty?
            entity.names.first.value
          elsif entity.respond_to?(:short) && entity.short
            entity.short
          elsif entity.respond_to?(:name)
            entity.name
          else
            "unknown-name"
          end
        end

        # Helper to get qudt entity name
        def get_qudt_entity_name(entity)
          case entity
          when Unitsdb::QudtUnit, Unitsdb::QudtQuantityKind, Unitsdb::QudtDimensionVector, Unitsdb::QudtSystemOfUnits
            entity.label || "No label"
          else
            "unknown-name"
          end
        end
      end
    end
  end
end
