# frozen_string_literal: true

require_relative "../base"

module Unitsdb
  module Commands
    module Validate
      class SiReferences < Unitsdb::Commands::Base
        def run
          # Load the database
          db = load_database(@options[:database])

          # Check for duplicate SI references
          duplicates = check_si_references(db)

          # Display results
          display_duplicate_results(duplicates)
        rescue Unitsdb::Errors::DatabaseError => e
          puts "Error: #{e.message}"
          exit(1)
        end

        private

        def check_si_references(db)
          duplicates = {}

          # Check units
          check_entity_si_references(db.units, "units", duplicates)

          # Check quantities
          check_entity_si_references(db.quantities, "quantities", duplicates)

          # Check prefixes
          check_entity_si_references(db.prefixes, "prefixes", duplicates)

          duplicates
        end

        def check_entity_si_references(entities, entity_type, duplicates)
          # Track SI references by URI
          si_refs = {}

          entities.each_with_index do |entity, index|
            # Skip if no references
            next unless entity.respond_to?(:references) && entity.references

            # Check each reference
            entity.references.each do |ref|
              # Only interested in si-digital-framework references
              next unless ref.authority == "si-digital-framework"

              # Get entity info for display
              entity_id = if entity.respond_to?(:identifiers) && entity.identifiers&.first.respond_to?(:id)
                            entity.identifiers.first.id
                          else
                            entity.short
                          end

              # Track this reference
              si_refs[ref.uri] ||= []
              si_refs[ref.uri] << {
                entity_id: entity_id,
                entity_name: entity.respond_to?(:names) ? entity.names.first : entity.short,
                index: index
              }
            end
          end

          # Find duplicates (URIs with more than one entity)
          si_refs.each do |uri, entities|
            next unless entities.size > 1

            # Record this duplicate
            duplicates[entity_type] ||= {}
            duplicates[entity_type][uri] = entities
          end
        end

        def display_duplicate_results(duplicates)
          if duplicates.empty?
            puts "No duplicate SI references found! Each SI reference URI is used by at most one entity of each type."
            return
          end

          puts "Found duplicate SI references:"

          duplicates.each do |entity_type, uri_duplicates|
            puts "\n  #{entity_type.capitalize}:"

            uri_duplicates.each do |uri, entities|
              puts "    SI URI: #{uri}"
              puts "    Used by #{entities.size} entities:"

              entities.each do |entity|
                puts "      - #{entity[:entity_id]} (#{entity[:entity_name]}) at index #{entity[:index]}"
              end
              puts ""
            end
          end

          puts "\nEach SI digital framework reference should be used by at most one entity of each type."
          puts "Please fix the duplicates by either removing the reference from all but one entity,"
          puts "or by updating the references to use different URIs appropriate for each entity."
        end
      end
    end
  end
end
