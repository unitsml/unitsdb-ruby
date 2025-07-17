# frozen_string_literal: true

require_relative "../base"

module Unitsdb
  module Commands
    module Validate
      class UcumReferences < Unitsdb::Commands::Base
        def run
          # Load the database
          db = load_database(@options[:database])

          # Check for duplicate UCUM references
          duplicates = check_ucum_references(db)

          # Display results
          display_duplicate_results(duplicates)
        rescue Unitsdb::Errors::DatabaseError => e
          puts "Error: #{e.message}"
          exit(1)
        end

        private

        def check_ucum_references(db)
          duplicates = {}

          # Check units
          check_entity_ucum_references(db.units, "units", duplicates)

          # Check prefixes
          check_entity_ucum_references(db.prefixes, "prefixes", duplicates)

          duplicates
        end

        def check_entity_ucum_references(entities, entity_type, duplicates)
          # Track UCUM references by code
          ucum_refs = {}

          entities.each_with_index do |entity, index|
            # Skip if no external references
            next unless entity.respond_to?(:external_references) && entity.external_references

            # Check each external reference
            entity.external_references.each do |ref|
              # Only interested in ucum references
              next unless ref.authority == "ucum"

              # Get entity info for display
              entity_id = entity.respond_to?(:id) ? entity.id : entity.short
              entity_name = if entity.respond_to?(:names) && entity.names&.first
                              entity.names.first.respond_to?(:name) ? entity.names.first.name : entity.names.first
                            else
                              entity.short
                            end

              # Track this reference
              ucum_refs[ref.code] ||= []
              ucum_refs[ref.code] << {
                entity_id: entity_id,
                entity_name: entity_name,
                index: index,
              }
            end
          end

          # Find duplicates (codes with more than one entity)
          ucum_refs.each do |code, entities|
            next unless entities.size > 1

            # Record this duplicate
            duplicates[entity_type] ||= {}
            duplicates[entity_type][code] = entities
          end
        end

        def display_duplicate_results(duplicates)
          if duplicates.empty?
            puts "No duplicate UCUM references found! Each UCUM reference code is used by at most one entity of each type."
            return
          end

          puts "Found duplicate UCUM references:"

          duplicates.each do |entity_type, code_duplicates|
            puts "\n  #{entity_type.capitalize}:"

            code_duplicates.each do |code, entities|
              puts "    UCUM Code: #{code}"
              puts "    Used by #{entities.size} entities:"

              entities.each do |entity|
                puts "      - #{entity[:entity_id]} (#{entity[:entity_name]}) at index #{entity[:index]}"
              end
              puts ""
            end
          end

          puts "\nEach UCUM reference should be used by at most one entity of each type."
          puts "Please fix the duplicates by either removing the reference from all but one entity,"
          puts "or by updating the references to use different codes appropriate for each entity."
        end
      end
    end
  end
end
