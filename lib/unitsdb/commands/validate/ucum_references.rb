# frozen_string_literal: true

module Unitsdb
  module Commands
    module Validate
      # `unitsdb validate ucum_references`. Checks that no UCUM
      # reference code is used by more than one Unit or Prefix.
      class UcumReferences < Unitsdb::Commands::Base
        AUTHORITY = "ucum"
        ENTITY_COLLECTIONS = %i[units prefixes].freeze

        def run
          db = load_database(@options[:database])
          duplicates = scan(db)
          display(duplicates)
        rescue Unitsdb::Errors::DatabaseError => e
          raise Unitsdb::Errors::ValidationError,
                "Failed to validate UCUM references: #{e.message}"
        end

        private

        def scan(db)
          {}.tap do |duplicates|
            ENTITY_COLLECTIONS.each do |name|
              collection = db.collection(name) || []
              dup = scan_collection(collection)
              duplicates[name.to_s] = dup unless dup.empty?
            end
          end
        end

        def scan_collection(entities)
          by_code = {}
          entities.each_with_index do |entity, index|
            refs = entity.references || []
            refs.each do |ref|
              next unless ref.authority == AUTHORITY

              (by_code[ref.uri] ||= []) << {
                entity_id: entity.identifiers.first&.id || entity.short,
                entity_name: entity.names.first&.value || entity.short,
                index: index,
              }
            end
          end
          by_code.reject { |_, refs| refs.size == 1 }
        end

        def display(duplicates)
          if duplicates.empty?
            puts "No duplicate UCUM references found! " \
                 "Each UCUM reference code is used by at most one entity of each type."
            return
          end

          puts "Found duplicate UCUM references:"
          duplicates.each do |entity_type, code_duplicates|
            puts "\n  #{entity_type.capitalize}:"
            code_duplicates.each do |code, refs|
              puts "    UCUM Code: #{code}"
              puts "    Used by #{refs.size} entities:"
              refs.each { |r| puts "      - #{r[:entity_id]} (#{r[:entity_name]}) at index #{r[:index]}" }
              puts ""
            end
          end
        end
      end
    end
  end
end
