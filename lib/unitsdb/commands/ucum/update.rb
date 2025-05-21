# frozen_string_literal: true

require_relative "../base"
require_relative "../../database"
require_relative "xml_parser"
require_relative "matcher"
require_relative "updater"
require "fileutils"

module Unitsdb
  module Commands
    module Ucum
      # Command to update UnitsDB with UCUM references
      class Update < Base
        # Constants
        ENTITY_TYPES = %w[units prefixes].freeze

        def run
          # Get options
          entity_type = @options[:entity_type]&.downcase
          database_path = @options[:database]
          ucum_file = @options[:ucum_file]
          output_dir = @options[:output_dir] || database_path
          include_potential = @options[:include_potential_matches] || false

          # Validate database path
          unless File.exist?(database_path) && Dir.exist?(database_path)
            puts "Database directory path: #{database_path}"
            puts "ERROR: Database directory not found: #{database_path}"
            return 1
          end
          puts "Using database directory: #{database_path}"

          # Validate UCUM file
          unless File.exist?(ucum_file)
            puts "ERROR: UCUM file not found: #{ucum_file}"
            return 1
          end
          puts "Using UCUM file: #{ucum_file}"
          puts "Include potential matches: #{include_potential ? "Yes" : "No"}"

          # Parse UCUM XML file
          ucum_data = XmlParser.parse_ucum_file(ucum_file)

          # Process entity types
          if entity_type && ENTITY_TYPES.include?(entity_type)
            process_entity_type(entity_type, ucum_data, output_dir, include_potential)
          else
            ENTITY_TYPES.each do |type|
              process_entity_type(type, ucum_data, output_dir, include_potential)
            end
          end

          0
        end

        private

        def process_entity_type(entity_type, ucum_data, output_dir, include_potential)
          puts "\n========== Processing #{entity_type.upcase} References =========="

          # Get entities
          klass = Unitsdb.const_get(entity_type.capitalize)
          yaml_path = File.join(@options[:database], "#{entity_type}.yaml")
          entity_collection = klass.from_yaml(File.read(yaml_path))

          ucum_entities = XmlParser.get_entities_from_ucum(entity_type, ucum_data)

          return if ucum_entities.nil? || ucum_entities.empty?

          # Match entities
          _, missing_refs, = Matcher.match_db_to_ucum(entity_type, ucum_entities, entity_collection)

          # Create output directory if it doesn't exist
          FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

          # Update references in UnitsDB entities
          output_file = File.join(output_dir, "#{entity_type}.yaml")
          Updater.update_references(entity_type, missing_refs, entity_collection, output_file, include_potential)
        end
      end
    end
  end
end
