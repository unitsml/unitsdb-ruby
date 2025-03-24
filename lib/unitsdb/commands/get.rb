# frozen_string_literal: true

require_relative "base"
require "json"
require_relative "../errors"

module Unitsdb
  module Commands
    class Get < Base
      def get(id)
        # Database path is guaranteed by Thor's global option
        id_type = @options[:id_type]
        format = @options[:format] || "text"

        begin
          database = load_database(@options[:database])

          # Search by ID
          entity = database.get_by_id(id: id, type: id_type)

          unless entity
            puts "No entity found with ID: '#{id}'"
            return
          end

          # Output based on format
          if %w[json yaml].include?(format.downcase)
            begin
              puts entity.send("to_#{format.downcase}")
              return
            rescue NoMethodError
              puts "Error: Unable to convert entity to #{format} format"
              exit(1)
            end
          end

          # Default text output
          print_entity_details(entity)
        rescue Unitsdb::Errors::DatabaseError => e
          puts "Error: #{e.message}"
          exit(1)
        rescue StandardError => e
          puts "Error searching database: #{e.message}"
          exit(1)
        end
      end

      private

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
          puts "      - #{ref.type}: #{ref.uri}"
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
    end
  end
end
