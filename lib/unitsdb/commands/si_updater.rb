# frozen_string_literal: true

require "yaml"
require "fileutils"

module Unitsdb
  module Commands
    # Updater for SI references in YAML
    module SiUpdater
      SI_AUTHORITY = "si-digital-framework"

      module_function

      # Update references in YAML file (TTL → DB direction)
      def update_references(entity_type, missing_matches, db_entities, output_file, include_potential = false)
        # Use the database objects to access the data directly
        original_yaml_file = db_entities.first.send(:yaml_file) if db_entities&.first.respond_to?(:yaml_file, true)

        # If we can't get the path from the database object, use the output file path as a fallback
        if original_yaml_file.nil? || !File.exist?(original_yaml_file)
          puts "Warning: Could not determine original YAML file path. Using output file as template."
          original_yaml_file = output_file

          # Create an empty template if output file doesn't exist
          unless File.exist?(original_yaml_file)
            FileUtils.mkdir_p(File.dirname(original_yaml_file))
            File.write(original_yaml_file, { entity_type => [] }.to_yaml)
          end
        end

        # Load the original YAML file
        yaml_content = File.read(original_yaml_file)
        output_data = YAML.safe_load(yaml_content)

        # Group by entity ID to avoid duplicates
        grouped_matches = missing_matches.group_by { |match| match[:entity_id] }

        # Process each entity that needs updating
        grouped_matches.each do |entity_id, matches|
          # Filter matches based on include_potential parameter
          filtered_matches = matches.select do |match|
            # Check if it's an exact match or if we're including potential matches
            match_details = match[:match_details]
            if match_details&.dig(:exact) == false || %w[symbol_match
                                                         partial_match].include?(match_details&.dig(:match_desc) || "")
              include_potential
            else
              true
            end
          end

          # Skip if no matches after filtering
          next if filtered_matches.empty?

          # Find the entity in the array under the entity_type key
          entity_index = output_data[entity_type].find_index do |e|
            # Find entity with matching identifier
            e["identifiers"]&.any? { |id| id["id"] == entity_id }
          end

          next unless entity_index

          # Get the entity
          entity = output_data[entity_type][entity_index]

          # Initialize references array if it doesn't exist
          entity["references"] ||= []

          # Add new references
          filtered_matches.each do |match|
            # If this match has multiple SI references, add them all
            if match[:multiple_si]
              match[:multiple_si].each do |si_data|
                # Check if reference already exists
                next if entity["references"].any? do |ref|
                  ref["uri"] == si_data[:uri] && ref["authority"] == SI_AUTHORITY
                end

                # Add new reference
                entity["references"] << {
                  "uri" => si_data[:uri],
                  "type" => "normative",
                  "authority" => SI_AUTHORITY
                }
              end
            else
              # Check if reference already exists
              next if entity["references"].any? do |ref|
                ref["uri"] == match[:si_uri] && ref["authority"] == SI_AUTHORITY
              end

              # Add new reference
              entity["references"] << {
                "uri" => match[:si_uri],
                "type" => "normative",
                "authority" => SI_AUTHORITY
              }
            end
          end
        end

        write_yaml_file(output_file, output_data)
      end

      # Update references in YAML file (DB → TTL direction)
      def update_db_references(entity_type, missing_refs, output_file, include_potential = false)
        # Try to get the original YAML file from the first entity
        first_entity = missing_refs.first&.dig(:db_entity)
        original_yaml_file = first_entity.send(:yaml_file) if first_entity.respond_to?(:yaml_file, true)

        # If we can't get the path from the database object, use the output file path as a fallback
        if original_yaml_file.nil? || !File.exist?(original_yaml_file)
          puts "Warning: Could not determine original YAML file path. Using output file as template."
          original_yaml_file = output_file

          # Create an empty template if output file doesn't exist
          unless File.exist?(original_yaml_file)
            FileUtils.mkdir_p(File.dirname(original_yaml_file))
            File.write(original_yaml_file, { entity_type => [] }.to_yaml)
          end
        end

        # Load the original YAML file
        yaml_content = File.read(original_yaml_file)
        output_data = YAML.safe_load(yaml_content)

        # Group by entity ID to avoid duplicates
        missing_refs_by_id = {}

        missing_refs.each do |match|
          entity_id = match[:entity_id] || match[:db_entity].short
          ttl_entities = match[:ttl_entities]
          match_types = match[:match_types] || {}

          # Filter TTL entities based on include_potential parameter
          filtered_ttl_entities = ttl_entities.select do |ttl_entity|
            # Check if it's an exact match or if we're including potential matches
            match_type = match_types[ttl_entity[:uri]] || "Exact match" # Default to exact match
            match_pair_key = "#{entity_id}:#{ttl_entity[:uri]}"
            match_details = Unitsdb::Commands::SiMatcher.instance_variable_get(:@match_details)&.dig(match_pair_key)

            if match_details && %w[symbol_match partial_match].include?(match_details[:match_desc])
              include_potential
            else
              match_type == "Exact match" || include_potential
            end
          end

          # Skip if no entities after filtering
          next if filtered_ttl_entities.empty?

          missing_refs_by_id[entity_id] ||= []

          # Add filtered matching TTL entities for this DB entity
          filtered_ttl_entities.each do |ttl_entity|
            missing_refs_by_id[entity_id] << {
              uri: ttl_entity[:uri],
              type: "normative",
              authority: SI_AUTHORITY
            }
          end
        end

        # Update the YAML content
        output_data[entity_type].each do |entity_yaml|
          # Find entity by ID or short
          entity_id = if entity_yaml["identifiers"]
                        begin
                          entity_yaml["identifiers"].first["id"]
                        rescue StandardError
                          nil
                        end
                      elsif entity_yaml["id"]
                        entity_yaml["id"]
                      end

          next unless entity_id && missing_refs_by_id.key?(entity_id)

          # Add references
          entity_yaml["references"] ||= []

          missing_refs_by_id[entity_id].each do |ref|
            # Check if this reference already exists
            next if entity_yaml["references"].any? do |existing_ref|
              existing_ref["uri"] == ref[:uri] &&
              existing_ref["authority"] == ref[:authority]
            end

            # Add the reference
            entity_yaml["references"] << {
              "uri" => ref[:uri],
              "type" => ref[:type],
              "authority" => ref[:authority]
            }
          end
        end

        write_yaml_file(output_file, output_data)
      end

      # Helper to write YAML file
      def write_yaml_file(output_file, output_data)
        # Ensure the output directory exists
        output_dir = File.dirname(output_file)
        FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

        # Write to YAML file
        File.write(output_file, output_data.to_yaml)
      end
    end
  end
end
