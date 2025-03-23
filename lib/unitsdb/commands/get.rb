# frozen_string_literal: true

require_relative "base"
require "json"

module Unitsdb
  module Commands
    class Get < Base
      desc "get ID", "Get detailed information about a specific entity"
      option :id_type, type: :string, desc: "Identifier type to filter by"
      option :format, type: :string, default: "text", desc: "Output format (text, json, yaml)"

      def get(id, options = {})
        id_type = options[:id_type]
        format = options[:format] || "text"

        database = load_database(options[:database] || ".")
        entity = database.get_by_id(id: id, type: id_type)

        # Early return if no entity found
        unless entity
          puts "No entity found with ID: '#{id}'"
          return
        end

        # Process the found entity with format-specific output
        if %w[json yaml].include?(format.downcase)
          puts entity.send("to_#{format.downcase}")
          return
        end

        # Default to text output
        print_entity_details(entity)
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
    end
  end
end
