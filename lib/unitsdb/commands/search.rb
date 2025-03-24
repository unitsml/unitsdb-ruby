# frozen_string_literal: true

require_relative "base"
require "json"
require_relative "../errors"

module Unitsdb
  module Commands
    class Search < Base
      def run(query)
        # Database path is guaranteed by Thor's global option

        type = @options[:type]
        id = @options[:id]
        id_type = @options[:id_type]
        format = @options[:format] || "text"

        begin
          database = load_database(@options[:database])

          # Search by ID (early return)
          if id
            entity = database.get_by_id(id: id, type: id_type)

            unless entity
              puts "No entity found with ID: '#{id}'"
              return
            end

            # Use the same output logic as the Get command
            if %w[json yaml].include?(format.downcase)
              begin
                puts entity.send("to_#{format.downcase}")
                return
              rescue NoMethodError
                puts "Error: Unable to convert entity to #{format} format"
                exit(1)
              end
            end

            print_entity_details(entity)
            return
          end

          # Regular text search
          results = database.search(text: query, type: type)

          # Early return for empty results
          if results.empty?
            puts "No results found for '#{query}'"
            return
          end

          # Format-specific output
          if %w[json yaml].include?(format.downcase)
            temp_db = create_temporary_database(results)
            puts temp_db.send("to_#{format.downcase}")
            return
          end

          # Default text output
          puts "Found #{results.size} result(s) for '#{query}':"
          results.each do |entity|
            print_entity_with_ids(entity)
          end
        rescue Unitsdb::Errors::DatabaseError => e
          puts "Error: #{e.message}"
          exit(1)
        rescue StandardError => e
          puts "Error searching database: #{e.message}"
          exit(1)
        end
      end

      private

      def print_entity_with_ids(entity)
        # Determine entity type
        entity_type = get_entity_type(entity)

        # Get name
        name = get_entity_name(entity)

        # Get all identifiers
        identifiers = entity.identifiers || []

        # Print entity information
        puts "  - #{entity_type}: #{name}"

        # Print each identifier on its own line for better readability
        if identifiers.empty?
          puts "    ID: None"
        else
          puts "    IDs:"
          identifiers.each do |id|
            puts "      - #{id.id} (Type: #{id.type || "N/A"})"
          end
        end

        # If entity has a short description, print it
        puts "    Description: #{entity.short}" if entity.respond_to?(:short) && entity.short && entity.short != name

        # Add a blank line for readability
        puts ""
      end

      def print_entity_details(entity)
        # Determine entity type
        entity_type = get_entity_type(entity)

        # Get name
        name = get_entity_name(entity)

        puts "Entity details:"
        puts "  - Type: #{entity_type}"
        puts "  - Name: #{name}"

        # Print description if available
        puts "  - Description: #{entity.short}" if entity.respond_to?(:short) && entity.short && entity.short != name

        # Print all identifiers
        if entity.identifiers&.any?
          puts "  - Identifiers:"
          entity.identifiers.each do |id|
            puts "      - #{id.id} (Type: #{id.type || "N/A"})"
          end
        else
          puts "  - Identifiers: None"
        end

        # Print additional properties based on entity type
        case entity
        when Unitsdb::Unit
          puts "  - Symbols:" if entity.respond_to?(:symbols) && entity.symbols&.any?
          entity.symbols.each { |s| puts "      - #{s}" } if entity.respond_to?(:symbols) && entity.symbols&.any?

          puts "  - Definition: #{entity.definition}" if entity.respond_to?(:definition) && entity.definition

          if entity.respond_to?(:dimensions) && entity.dimensions&.any?
            puts "  - Dimensions:"
            entity.dimensions.each { |d| puts "      - #{d}" }
          end
        when Unitsdb::Quantity
          puts "  - Dimensions: #{entity.dimension}" if entity.respond_to?(:dimension) && entity.dimension
        when Unitsdb::Prefix
          puts "  - Value: #{entity.value}" if entity.respond_to?(:value) && entity.value
          puts "  - Symbol: #{entity.symbol}" if entity.respond_to?(:symbol) && entity.symbol
        when Unitsdb::Dimension
          # Any dimension-specific properties
        when Unitsdb::UnitSystem
          puts "  - Organization: #{entity.organization}" if entity.respond_to?(:organization) && entity.organization
        end

        # Print references if available
        return unless entity.respond_to?(:references) && entity.references&.any?

        puts "  - References:"
        entity.references.each do |ref|
          puts "      - #{ref.type}: #{ref.id}"
        end
      end

      def get_entity_type(entity)
        case entity
        when Unitsdb::Unit
          "Unit"
        when Unitsdb::Prefix
          "Prefix"
        when Unitsdb::Quantity
          "Quantity"
        when Unitsdb::Dimension
          "Dimension"
        when Unitsdb::UnitSystem
          "UnitSystem"
        else
          "Unknown"
        end
      end

      def get_entity_name(entity)
        # Using early returns is still preferable for simple conditions
        return entity.names.first if entity.respond_to?(:names) && entity.names&.any?
        return entity.name if entity.respond_to?(:name) && entity.name
        return entity.short if entity.respond_to?(:short) && entity.short

        "N/A" # Default if no name found
      end

      def create_temporary_database(results)
        temp_db = Unitsdb::Database.new

        # Initialize collections
        temp_db.units = []
        temp_db.prefixes = []
        temp_db.quantities = []
        temp_db.dimensions = []
        temp_db.unit_systems = []

        # Add results to appropriate collection based on type using case statement
        results.each do |entity|
          case entity
          when Unitsdb::Unit
            temp_db.units << entity
          when Unitsdb::Prefix
            temp_db.prefixes << entity
          when Unitsdb::Quantity
            temp_db.quantities << entity
          when Unitsdb::Dimension
            temp_db.dimensions << entity
          when Unitsdb::UnitSystem
            temp_db.unit_systems << entity
          end
        end

        temp_db
      end
    end
  end
end
