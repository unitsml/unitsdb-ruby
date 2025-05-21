# frozen_string_literal: true

module Unitsdb
  module Commands
    module Ucum
      # Formats output for UCUM matching results
      module Formatter
        module_function

        # Print a direction header (UnitsDB → UCUM or UCUM → UnitsDB)
        def print_direction_header(direction)
          puts "\n=== #{direction} ===\n"
        end

        # Display results for UCUM → UnitsDB matching
        def display_ucum_results(entity_type, matches, missing_matches, unmatched_ucum)
          puts "\nResults for #{entity_type.capitalize} (UCUM → UnitsDB):"
          puts "  Matched: #{matches.size}"
          puts "  Missing matches (could be added): #{missing_matches.size}"
          puts "  Unmatched UCUM entities: #{unmatched_ucum.size}"

          unless unmatched_ucum.empty?
            puts "\nUnmatched UCUM #{entity_type}:"
            unmatched_ucum.each do |entity|
              case entity
              when Unitsdb::UcumPrefix
                puts "  - #{entity.name} (#{entity.code_sensitive})"
              when Unitsdb::UcumBaseUnit
                puts "  - #{entity.name} (#{entity.code_sensitive}, dimension: #{entity.dimension})"
              when Unitsdb::UcumUnit
                name = entity.name.is_a?(Array) ? entity.name.first : entity.name
                puts "  - #{name} (#{entity.code_sensitive}, class: #{entity.klass})"
              else
                puts "  - Unknown entity type"
              end
            end
          end

          return if missing_matches.empty?

          puts "\nPotential additions (UCUM #{entity_type} that could be added to UnitsDB):"
          missing_matches.each do |match|
            ucum_entity = match[:ucum_entity]
            db_entity = match[:db_entity]

            # Get entity IDs and names
            db_id = get_db_entity_id(db_entity)
            db_name = get_db_entity_name(db_entity)
            ucum_name = get_ucum_entity_name(ucum_entity)
            ucum_code = ucum_entity.respond_to?(:code_sensitive) ? ucum_entity.code_sensitive : "unknown"

            case ucum_entity
            when Unitsdb::UcumPrefix
              puts "  - UnitsDB prefix '#{db_name}' (#{db_id}) → UCUM prefix '#{ucum_name}' (#{ucum_code})"
            when Unitsdb::UcumBaseUnit
              puts "  - UnitsDB unit '#{db_name}' (#{db_id}) → UCUM base unit '#{ucum_name}' (#{ucum_code})"
            when Unitsdb::UcumUnit
              puts "  - UnitsDB unit '#{db_name}' (#{db_id}) → UCUM unit '#{ucum_name}' (#{ucum_code})"
            end
          end
        end

        # Display results for UnitsDB → UCUM matching
        def display_db_results(entity_type, matches, missing_refs, unmatched_db)
          puts "\nResults for #{entity_type.capitalize} (UnitsDB → UCUM):"
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

          puts "\nPotential references (UCUM references that could be added to UnitsDB):"
          missing_refs.each do |match|
            ucum_entity = match[:ucum_entity]
            db_entity = match[:db_entity]

            # Get entity IDs and names
            db_id = get_db_entity_id(db_entity)
            db_name = get_db_entity_name(db_entity)
            ucum_name = get_ucum_entity_name(ucum_entity)
            ucum_code = ucum_entity.respond_to?(:code_sensitive) ? ucum_entity.code_sensitive : "unknown"

            case ucum_entity
            when Unitsdb::UcumPrefix
              puts "  - UnitsDB prefix '#{db_name}' (#{db_id}) → UCUM prefix '#{ucum_name}' (#{ucum_code})"
            when Unitsdb::UcumBaseUnit
              puts "  - UnitsDB unit '#{db_name}' (#{db_id}) → UCUM base unit '#{ucum_name}' (#{ucum_code})"
            when Unitsdb::UcumUnit
              puts "  - UnitsDB unit '#{db_name}' (#{db_id}) → UCUM unit '#{ucum_name}' (#{ucum_code})"
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

        # Helper to get ucum entity name
        def get_ucum_entity_name(entity)
          case entity
          when Unitsdb::UcumPrefix, Unitsdb::UcumBaseUnit
            entity.name
          when Unitsdb::UcumUnit
            entity.name.is_a?(Array) ? entity.name.first : entity.name
          else
            "unknown-name"
          end
        end
      end
    end
  end
end
