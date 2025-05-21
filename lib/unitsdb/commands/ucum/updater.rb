# frozen_string_literal: true

require "yaml"
require "fileutils"

module Unitsdb
  module Commands
    module Ucum
      # Updater for adding UCUM references to UnitsDB entities
      module Updater
        UCUM_AUTHORITY = "ucum"

        module_function

        # Update references in UnitsDB entities with UCUM references
        def update_references(entity_type, matches, db_entities, output_file, include_potential = false)
          puts "Updating UCUM references for #{entity_type}..."

          # Create a map of entity IDs to their UCUM references
          entity_references = {}

          # Process each match
          matches.each do |match|
            db_entity = match[:db_entity]
            ucum_entity = match[:ucum_entity]

            # Skip potential matches unless specified
            next if match[:potential] && !include_potential

            # Get entity ID
            entity_id = get_entity_id(db_entity)
            next unless entity_id

            # Initialize references for this entity
            entity_references[entity_id] = ExternalReference.new(
              uri: ucum_entity.identifier,
              type: "informative",
              authority: UCUM_AUTHORITY
            )
          end

          # Update the YAML content
          db_entities.send(entity_type).each do |entity|
            # Find entity by ID
            entity_id = if entity.identifiers
                          begin
                            entity.identifiers.first.id
                          rescue StandardError
                            nil
                          end
                        end

            next unless entity_id && entity_references.key?(entity_id)

            # Initialize references array if it doesn't exist
            entity.references ||= []

            # Add new references
            if (ext_ref = entity_references[entity_id])
              if entity.references.detect { |ref| ref.uri == ext_ref.uri && ref.authority == ext_ref.authority }
                # Skip if reference already exists
                puts "Reference already exists for entity ID: #{entity_id}"
              else
                # Add the reference
                puts "Adding reference for entity ID: #{entity_id}, URI: #{ext_ref.uri}, Authority: #{ext_ref.authority}"
                entity.references << ext_ref
              end
            end
          end

          # Write to YAML file
          write_yaml_file(output_file, db_entities)

          puts "Added #{entity_references.values.flatten.size} UCUM references to #{entity_type}"
        end

        # Helper to write YAML file
        def write_yaml_file(output_file, output_data)
          # Ensure the output directory exists
          output_dir = File.dirname(output_file)
          FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

          # Write to YAML file
          File.write(output_file, output_data.to_yaml)
        end

        # Get entity ID (either from identifiers array or directly)
        def get_entity_id(entity)
          if entity.respond_to?(:identifiers) && entity.identifiers && !entity.identifiers.empty?
            entity.identifiers.first.id
          elsif entity.respond_to?(:id)
            entity.id
          end
        end
      end
    end
  end
end
