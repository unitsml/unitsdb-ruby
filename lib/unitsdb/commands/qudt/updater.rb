# frozen_string_literal: true

require "yaml"
require "fileutils"

module Unitsdb
  module Commands
    module Qudt
      # Updater for adding QUDT references to UnitsDB entities
      module Updater
        QUDT_AUTHORITY = "qudt"

        module_function

        # Update references in UnitsDB entities with QUDT references
        def update_references(entity_type, matches, db_entities, output_file, include_potential = false)
          puts "Updating QUDT references for #{entity_type}..."

          # Get the original YAML file path from the database entities
          original_yaml_file = get_original_yaml_file(db_entities, output_file)

          # Load the original YAML file as plain data structures
          yaml_content = File.read(original_yaml_file)
          output_data = YAML.safe_load(yaml_content)

          # Create a map of entity IDs to their QUDT references
          entity_references = {}

          # Process each match
          matches.each do |match|
            db_entity = match[:db_entity]
            qudt_entity = match[:qudt_entity]

            # Skip potential matches unless specified
            next if match[:potential] && !include_potential

            # Skip if entity has been manually verified
            if manually_verified?(db_entity)
              puts "Skipping manually verified entity: #{get_entity_id(db_entity)}"
              next
            end

            # Get entity ID
            entity_id = get_entity_id(db_entity)
            next unless entity_id

            # Store reference data as plain hash
            entity_references[entity_id] = {
              "uri" => qudt_entity.uri,
              "type" => "informative",
              "authority" => QUDT_AUTHORITY
            }
          end

          # Update the YAML content
          output_data[entity_type].each do |entity_yaml|
            # Find entity by ID
            entity_id = if entity_yaml["identifiers"]
                          begin
                            entity_yaml["identifiers"].first["id"]
                          rescue StandardError
                            nil
                          end
                        end

            next unless entity_id && entity_references.key?(entity_id)

            # Initialize references array if it doesn't exist
            entity_yaml["references"] ||= []

            # Add new references
            if (ext_ref = entity_references[entity_id])
              if entity_yaml["references"].any? { |ref| ref["uri"] == ext_ref["uri"] && ref["authority"] == ext_ref["authority"] }
                # Skip if reference already exists
                puts "Reference already exists for entity ID: #{entity_id}"
              else
                # Add the reference
                puts "Adding reference for entity ID: #{entity_id}, URI: #{ext_ref["uri"]}, Authority: #{ext_ref["authority"]}"
                entity_yaml["references"] << ext_ref
              end
            end
          end

          # Write to YAML file
          write_yaml_file(output_file, output_data)

          puts "Added #{entity_references.values.size} QUDT references to #{entity_type}"
        end

        # Helper to write YAML file
        def write_yaml_file(output_file, output_data)
          # Ensure the output directory exists
          output_dir = File.dirname(output_file)
          FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

          # Write to YAML file with proper formatting
          yaml_content = output_data.to_yaml

          # Preserve existing schema header or add default one
          yaml_content = preserve_schema_header(output_file, yaml_content)

          File.write(output_file, yaml_content)
        end

        # Preserve existing schema header or add default one
        def preserve_schema_header(original_file, yaml_content)
          schema_header = nil

          # Extract existing schema header if file exists
          if File.exist?(original_file)
            original_content = File.read(original_file)
            if (match = original_content.match(/^# yaml-language-server: \$schema=.+$/))
              schema_header = match[0]
            end
          end

          # Remove any existing schema header from new content to avoid duplication
          yaml_content = yaml_content.gsub(/^# yaml-language-server: \$schema=.+$\n/, '')

          # Add preserved or default schema header
          if schema_header
            "#{schema_header}\n#{yaml_content}"
          else
            entity_type = File.basename(original_file, '.yaml')
            "# yaml-language-server: $schema=schemas/#{entity_type}-schema.yaml\n#{yaml_content}"
          end
        end

        # Get the original YAML file path
        def get_original_yaml_file(db_entities, output_file)
          # The database path should be available from the update command
          # We need to construct the path to the original YAML file
          entity_type = File.basename(output_file, '.yaml')

          # Try to find the original file in the database directory
          # Look for it relative to where we expect it to be
          database_dir = nil

          # Try to get database directory from environment or assume it's the fixtures
          if ENV['UNITSDB_DATABASE_PATH']
            database_dir = ENV['UNITSDB_DATABASE_PATH']
          else
            # Default to the fixtures directory for testing
            database_dir = File.join(File.dirname(__FILE__), '../../../spec/fixtures/unitsdb')
          end

          original_yaml_file = File.join(database_dir, "#{entity_type}.yaml")

          # If that doesn't exist, try to find it relative to the current working directory
          unless File.exist?(original_yaml_file)
            original_yaml_file = File.join('spec/fixtures/unitsdb', "#{entity_type}.yaml")
          end

          # If still not found, create a fallback
          unless File.exist?(original_yaml_file)
            puts "Warning: Could not find original YAML file. Creating empty template."
            original_yaml_file = output_file
            FileUtils.mkdir_p(File.dirname(original_yaml_file))
            File.write(original_yaml_file, { entity_type => [] }.to_yaml)
          end

          puts "Using original YAML file: #{original_yaml_file}"
          original_yaml_file
        end

        # Get entity ID (either from identifiers array or directly)
        def get_entity_id(entity)
          if entity.respond_to?(:identifiers) && entity.identifiers && !entity.identifiers.empty?
            entity.identifiers.first.id
          elsif entity.respond_to?(:id)
            entity.id
          end
        end

        # Check if an entity has been manually verified (has a special flag)
        def manually_verified?(entity)
          return false unless entity.respond_to?(:references) && entity.references

          entity.references.any? { |ref| ref.authority == QUDT_AUTHORITY && ref.respond_to?(:verified) && ref.verified }
        end
      end
    end
  end
end
