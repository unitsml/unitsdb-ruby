# frozen_string_literal: true

require_relative "../base"
require_relative "../../database"
require_relative "../../errors"
require_relative "ttl_parser"
require_relative "matcher"
require_relative "updater"
require "fileutils"

module Unitsdb
  module Commands
    module Qudt
      class Update < Base
        # Constants
        ENTITY_TYPES = %w[units quantities dimensions unit_systems
                          prefixes].freeze

        def run
          # Get options
          entity_type = @options[:entity_type]&.downcase
          output_dir = @options[:output_dir]
          include_potential = @options[:include_potential_matches] || false
          database_path = @options[:database]
          ttl_dir = @options[:ttl_dir]
          source_type = ttl_dir ? :file : :url

          # Validate parameters
          validate_parameters(ttl_dir, source_type)

          # Use the path as-is without expansion
          puts "Using database directory: #{database_path}"

          @db = Unitsdb::Database.from_db(database_path)

          # Set output directory to database path if not specified
          output_dir ||= database_path

          if source_type == :file
            puts "Using QUDT TTL directory: #{ttl_dir}"
          else
            puts "Downloading QUDT vocabularies from online sources"
          end
          puts "Output directory: #{output_dir}"
          puts "Include potential matches: #{include_potential ? 'Yes' : 'No'}"

          # Parse QUDT vocabularies
          qudt_data = TtlParser.parse_qudt_vocabularies(
            source_type: source_type, ttl_dir: ttl_dir,
          )

          # Process entity types
          process_entities(entity_type, qudt_data, output_dir,
                           include_potential)
        end

        private

        # Process all entity types or a specific one
        def process_entities(entity_type, qudt_data, output_dir,
include_potential)
          if entity_type && ENTITY_TYPES.include?(entity_type)
            process_entity_type(entity_type, qudt_data, output_dir,
                                include_potential)
          else
            ENTITY_TYPES.each do |type|
              process_entity_type(type, qudt_data, output_dir,
                                  include_potential)
            end
          end
        end

        # Process a specific entity type
        def process_entity_type(entity_type, qudt_data, output_dir,
include_potential = false)
          puts "\n========== Updating #{entity_type.upcase} References ==========\n"

          # Get entities from the specific YAML file (like UCUM does)
          class_name = case entity_type
                       when "units" then "Units"
                       when "quantities" then "Quantities"
                       when "dimensions" then "Dimensions"
                       when "unit_systems" then "UnitSystems"
                       when "prefixes" then "Prefixes"
                       else entity_type.capitalize
                       end
          klass = Unitsdb.const_get(class_name)
          yaml_path = File.join(@options[:database], "#{entity_type}.yaml")
          entity_collection = klass.from_yaml(File.read(yaml_path))

          qudt_entities = TtlParser.get_entities_from_qudt(entity_type,
                                                           qudt_data)

          puts "Found #{qudt_entities.size} #{entity_type} in QUDT"
          puts "Found #{entity_collection.send(entity_type).size} #{entity_type} in database"

          # Match UnitsDB entities to QUDT entities
          matches, missing_refs, unmatched_db = Matcher.match_db_to_qudt(
            entity_type, qudt_entities, entity_collection.send(entity_type)
          )

          puts "Matched: #{matches.size}"
          puts "Missing references (will be added): #{missing_refs.size}"
          puts "Unmatched UnitsDB entities: #{unmatched_db.size}"

          # Update references if there are missing references
          if missing_refs.empty?
            puts "No new QUDT references to add for #{entity_type}"
          else
            # Create output directory if it doesn't exist
            FileUtils.mkdir_p(output_dir)

            output_file = File.join(output_dir, "#{entity_type}.yaml")
            # Set environment variable so updater can find the original file
            ENV["UNITSDB_DATABASE_PATH"] = @options[:database]
            Updater.update_references(entity_type, missing_refs,
                                      entity_collection, output_file, include_potential)
            puts "Updated references written to #{output_file}"
          end
        end

        # Validation helpers
        def validate_parameters(ttl_dir, source_type)
          return unless source_type == :file && ttl_dir && !Dir.exist?(ttl_dir)

          puts "TTL directory not found: #{ttl_dir}"
          exit(1)
        end
      end
    end
  end
end
