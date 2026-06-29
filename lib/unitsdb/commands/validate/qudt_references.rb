# frozen_string_literal: true

module Unitsdb
  module Commands
    module Validate
      # `unitsdb validate qudt_references`. Checks that no QUDT
      # reference URI is used by more than one entity of a given type.
      class QudtReferences < Unitsdb::Commands::Base
        AUTHORITY = "qudt"

        def run
          db = load_database(@options[:database])
          duplicates = scan(db)
          display(duplicates)
        rescue Unitsdb::Errors::DatabaseError => e
          raise Unitsdb::Errors::ValidationError,
                "Failed to validate QUDT references: #{e.message}"
        end

        private

        def scan(db)
          {}.tap do |duplicates|
            Unitsdb::Database::COLLECTIONS.each do |name|
              collection = db.collection(name) || []
              dup = scan_collection(collection)
              duplicates[name.to_s] = dup unless dup.empty?
            end
          end
        end

        def scan_collection(entities)
          by_uri = {}
          entities.each_with_index do |entity, index|
            refs = entity.references || []
            refs.each do |ref|
              next unless ref.authority == AUTHORITY

              (by_uri[ref.uri] ||= []) << {
                entity_id: entity.identifiers.first&.id || entity.short,
                entity_name: entity.names.first&.value || entity.short,
                index: index,
              }
            end
          end
          by_uri.reject { |_, refs| refs.size == 1 }
        end

        def display(duplicates)
          if duplicates.empty?
            puts "No duplicate QUDT references found! " \
                 "Each QUDT reference URI is used by at most one entity of each type."
            return
          end

          puts "Found duplicate QUDT references:"
          duplicates.each do |entity_type, uri_duplicates|
            puts "\n  #{entity_type.capitalize}:"
            uri_duplicates.each do |uri, refs|
              puts "    QUDT URI: #{uri}"
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
