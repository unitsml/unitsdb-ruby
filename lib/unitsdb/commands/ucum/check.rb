# frozen_string_literal: true

require_relative "../base"
require_relative "../../database"
require_relative "../../errors"
require_relative "xml_parser"
require_relative "formatter"
require_relative "matcher"
require_relative "updater"
require "fileutils"

module Unitsdb
  module Commands
    module Ucum
      class Check < Base
        # Constants
        ENTITY_TYPES = %w[units prefixes].freeze

        def run
          # Get options
          entity_type = @options[:entity_type]&.downcase
          direction = @options[:direction]&.downcase || "both"
          output_dir = @options[:output_updated_database]
          include_potential = @options[:include_potential_matches] || false
          database_path = @options[:database]
          ucum_file = @options[:ucum_file]

          # Validate parameters
          validate_parameters(direction, ucum_file)

          # Use the path as-is without expansion
          puts "Using database directory: #{database_path}"

          @db = Unitsdb::Database.from_db(database_path)

          puts "Using UCUM file: #{ucum_file}"
          puts "Include potential matches: #{include_potential ? "Yes" : "No"}"

          # Parse UCUM XML file
          ucum_data = XmlParser.parse_ucum_file(ucum_file)

          # Process entity types
          process_entities(entity_type, ucum_data, direction, output_dir, include_potential)
        end

        private

        # Process all entity types or a specific one
        def process_entities(entity_type, ucum_data, direction, output_dir, include_potential)
          if entity_type && ENTITY_TYPES.include?(entity_type)
            process_entity_type(entity_type, ucum_data, direction, output_dir, include_potential)
          else
            ENTITY_TYPES.each do |type|
              process_entity_type(type, ucum_data, direction, output_dir, include_potential)
            end
          end
        end

        # Process a specific entity type
        def process_entity_type(entity_type, ucum_data, direction, output_dir, include_potential = false)
          puts "\n========== Processing #{entity_type.upcase} References ==========\n"

          db_entities = @db.send(entity_type)
          ucum_entities = XmlParser.get_entities_from_ucum(entity_type, ucum_data)

          puts "Found #{ucum_entities.size} #{entity_type} in UCUM"
          puts "Found #{db_entities.size} #{entity_type} in database"

          check_from_ucum(entity_type, ucum_entities, db_entities, output_dir, include_potential) if %w[from_ucum
                                                                                                        both].include?(direction)

          return unless %w[to_ucum both].include?(direction)

          check_to_ucum(entity_type, ucum_entities, db_entities, output_dir, include_potential)
        end

        # Validation helpers
        def validate_parameters(direction, ucum_file)
          unless %w[to_ucum from_ucum both].include?(direction)
            puts "Invalid direction: #{direction}. Must be one of: to_ucum, from_ucum, both"
            exit(1)
          end

          return if File.exist?(ucum_file)

          puts "UCUM file not found: #{ucum_file}"
          exit(1)
        end

        # Direction handler: UCUM → UnitsDB
        def check_from_ucum(entity_type, ucum_entities, db_entities, output_dir, include_potential = false)
          Formatter.print_direction_header("UCUM → UnitsDB")

          matches, missing_matches, unmatched_ucum = Matcher.match_ucum_to_db(entity_type, ucum_entities, db_entities)

          # Print results
          Formatter.display_ucum_results(entity_type, matches, missing_matches, unmatched_ucum)

          # Update references if needed
          return unless output_dir && !missing_matches.empty?

          output_file = File.join(output_dir, "#{entity_type}.yaml")
          Updater.update_references(entity_type, missing_matches, db_entities, output_file, include_potential)
          puts "\nUpdated references written to #{output_file}"
        end

        # Direction handler: UnitsDB → UCUM
        def check_to_ucum(entity_type, ucum_entities, db_entities, output_dir, include_potential = false)
          Formatter.print_direction_header("UnitsDB → UCUM")

          matches, missing_refs, unmatched_db = Matcher.match_db_to_ucum(entity_type, ucum_entities, db_entities)

          # Print results
          Formatter.display_db_results(entity_type, matches, missing_refs, unmatched_db)

          # Update references if needed
          return unless output_dir && !missing_refs.empty?

          output_file = File.join(output_dir, "#{entity_type}.yaml")
          Updater.update_references(entity_type, missing_refs, db_entities, output_file, include_potential)
          puts "\nUpdated references written to #{output_file}"
        end
      end
    end
  end
end
