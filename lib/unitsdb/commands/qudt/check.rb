# frozen_string_literal: true

require_relative "../base"
require_relative "../../database"
require_relative "../../errors"
require_relative "ttl_parser"
require_relative "formatter"
require_relative "matcher"
require_relative "updater"
require "fileutils"

module Unitsdb
  module Commands
    module Qudt
      class Check < Base
        # Constants
        ENTITY_TYPES = %w[units quantities dimensions unit_systems
                          prefixes].freeze

        def run
          # Get options
          entity_type = @options[:entity_type]&.downcase
          direction = @options[:direction]&.downcase || "both"
          output_dir = @options[:output_updated_database]
          include_potential = @options[:include_potential_matches] || false
          database_path = @options[:database]
          ttl_dir = @options[:ttl_dir]
          source_type = ttl_dir ? :file : :url

          # Validate parameters
          validate_parameters(direction, ttl_dir, source_type)

          # Use the path as-is without expansion
          puts "Using database directory: #{database_path}"

          @db = Unitsdb::Database.from_db(database_path)

          if source_type == :file
            puts "Using QUDT TTL directory: #{ttl_dir}"
          else
            puts "Downloading QUDT vocabularies from online sources"
          end
          puts "Include potential matches: #{include_potential ? 'Yes' : 'No'}"

          # Parse QUDT vocabularies
          qudt_data = TtlParser.parse_qudt_vocabularies(
            source_type: source_type, ttl_dir: ttl_dir,
          )

          # Process entity types
          process_entities(entity_type, qudt_data, direction, output_dir,
                           include_potential)
        end

        private

        # Process all entity types or a specific one
        def process_entities(entity_type, qudt_data, direction, output_dir,
include_potential)
          if entity_type && ENTITY_TYPES.include?(entity_type)
            process_entity_type(entity_type, qudt_data, direction, output_dir,
                                include_potential)
          else
            ENTITY_TYPES.each do |type|
              process_entity_type(type, qudt_data, direction, output_dir,
                                  include_potential)
            end
          end
        end

        # Process a specific entity type
        def process_entity_type(entity_type, qudt_data, direction, output_dir,
include_potential = false)
          puts "\n========== Processing #{entity_type.upcase} References ==========\n"

          db_entities = @db.send(entity_type)
          qudt_entities = TtlParser.get_entities_from_qudt(entity_type,
                                                           qudt_data)

          puts "Found #{qudt_entities.size} #{entity_type} in QUDT"
          puts "Found #{db_entities.size} #{entity_type} in database"

          if %w[from_qudt
                both].include?(direction)
            check_from_qudt(entity_type, qudt_entities, db_entities, output_dir,
                            include_potential)
          end

          return unless %w[to_qudt both].include?(direction)

          check_to_qudt(entity_type, qudt_entities, db_entities, output_dir,
                        include_potential)
        end

        # Validation helpers
        def validate_parameters(direction, ttl_dir, source_type)
          unless %w[to_qudt from_qudt both].include?(direction)
            puts "Invalid direction: #{direction}. Must be one of: to_qudt, from_qudt, both"
            exit(1)
          end

          return unless source_type == :file && ttl_dir && !Dir.exist?(ttl_dir)

          puts "TTL directory not found: #{ttl_dir}"
          exit(1)
        end

        # Direction handler: QUDT → UnitsDB
        def check_from_qudt(entity_type, qudt_entities, db_entities,
output_dir, include_potential = false)
          Formatter.print_direction_header("QUDT → UnitsDB")

          matches, missing_matches, unmatched_qudt = Matcher.match_qudt_to_db(
            entity_type, qudt_entities, db_entities
          )

          # Print results
          Formatter.display_qudt_results(entity_type, matches, missing_matches,
                                         unmatched_qudt)

          # Display detailed missing QUDT entities analysis
          Formatter.display_missing_qudt_entities(entity_type, unmatched_qudt)

          # Update references if needed
          return unless output_dir && !missing_matches.empty?

          output_file = File.join(output_dir, "#{entity_type}.yaml")
          Updater.update_references(entity_type, missing_matches, db_entities,
                                    output_file, include_potential)
          puts "\nUpdated references written to #{output_file}"
        end

        # Direction handler: UnitsDB → QUDT
        def check_to_qudt(entity_type, qudt_entities, db_entities, output_dir,
include_potential = false)
          Formatter.print_direction_header("UnitsDB → QUDT")

          matches, missing_refs, unmatched_db = Matcher.match_db_to_qudt(
            entity_type, qudt_entities, db_entities
          )

          # Print results
          Formatter.display_db_results(entity_type, matches, missing_refs,
                                       unmatched_db)

          # Update references if needed
          return unless output_dir && !missing_refs.empty?

          output_file = File.join(output_dir, "#{entity_type}.yaml")
          Updater.update_references(entity_type, missing_refs, db_entities,
                                    output_file, include_potential)
          puts "\nUpdated references written to #{output_file}"
        end
      end
    end
  end
end
