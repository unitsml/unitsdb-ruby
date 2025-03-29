# frozen_string_literal: true

require_relative "base"
require_relative "../database"
require_relative "../errors"
require_relative "si_ttl_parser"
require_relative "si_formatter"
require_relative "si_matcher"
require_relative "si_updater"

module Unitsdb
  module Commands
    class CheckSi < Base
      # Constants
      ENTITY_TYPES = %w[units quantities prefixes].freeze

      def run
        # Get options
        entity_type = @options[:entity_type]&.downcase
        direction = @options[:direction]&.downcase || "both"
        output_dir = @options[:output_updated_database]
        include_potential = @options[:include_potential_matches] || false
        database_path = @options[:database]
        ttl_dir = @options[:ttl_dir]

        # Validate parameters
        validate_parameters(direction, ttl_dir)

        # Use the path as-is without expansion
        puts "Using database directory: #{database_path}"

        @db = Unitsdb::Database.from_db(database_path)

        puts "Using TTL directory: #{ttl_dir}"
        puts "Include potential matches: #{include_potential ? "Yes" : "No"}"

        # Parse TTL files
        graph = SiTtlParser.parse_ttl_files(ttl_dir)

        # Process entity types
        process_entities(entity_type, graph, direction, output_dir, include_potential)
      end

      private

      # Process all entity types or a specific one
      def process_entities(entity_type, graph, direction, output_dir, include_potential)
        if entity_type && ENTITY_TYPES.include?(entity_type)
          process_entity_type(entity_type, graph, direction, output_dir, include_potential)
        else
          ENTITY_TYPES.each do |type|
            process_entity_type(type, graph, direction, output_dir, include_potential)
          end
        end
      end

      # Process a specific entity type
      def process_entity_type(entity_type, graph, direction, output_dir, include_potential = false)
        puts "\n========== Processing #{entity_type.upcase} References ==========\n"

        db_entities = @db.send(entity_type)
        ttl_entities = SiTtlParser.extract_entities_from_ttl(entity_type, graph)

        puts "Found #{ttl_entities.size} #{entity_type} in SI digital framework"
        puts "Found #{db_entities.size} #{entity_type} in database"

        check_from_si(entity_type, ttl_entities, db_entities, output_dir, include_potential) if %w[from_si
                                                                                                   both].include?(direction)

        return unless %w[to_si both].include?(direction)

        check_to_si(entity_type, ttl_entities, db_entities, output_dir, include_potential)
      end

      # Validation helpers
      def validate_parameters(direction, ttl_dir)
        unless %w[to_si from_si both].include?(direction)
          puts "Invalid direction: #{direction}. Must be one of: to_si, from_si, both"
          exit(1)
        end

        return if Dir.exist?(ttl_dir)

        puts "TTL directory not found: #{ttl_dir}"
        exit(1)
      end

      # Direction handler: TTL → DB
      def check_from_si(entity_type, ttl_entities, db_entities, output_dir, include_potential = false)
        SiFormatter.print_direction_header("SI → UnitsDB")

        matches, missing_matches, unmatched_ttl = SiMatcher.match_ttl_to_db(entity_type, ttl_entities, db_entities)

        # Print results
        SiFormatter.display_si_results(entity_type, matches, missing_matches, unmatched_ttl)

        # Update references if needed
        return unless output_dir && !missing_matches.empty?

        output_file = File.join(output_dir, "#{entity_type}.yaml")
        SiUpdater.update_references(entity_type, missing_matches, db_entities, output_file, include_potential,
                                    database_path)
        puts "\nUpdated references written to #{output_file}"
      end

      # Direction handler: DB → TTL
      def check_to_si(entity_type, ttl_entities, db_entities, output_dir, include_potential = false)
        SiFormatter.print_direction_header("UnitsDB → SI")

        matches, missing_refs, unmatched_db = SiMatcher.match_db_to_ttl(entity_type, ttl_entities, db_entities)

        # Print results
        SiFormatter.display_db_results(entity_type, matches, missing_refs, unmatched_db)

        # Update references if needed
        return unless output_dir && !missing_refs.empty?

        output_file = File.join(output_dir, "#{entity_type}.yaml")
        SiUpdater.update_db_references(entity_type, missing_refs, output_file, include_potential, @options[:database])
        puts "\nUpdated references written to #{output_file}"
      end
    end
  end
end
