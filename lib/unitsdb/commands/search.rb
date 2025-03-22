# frozen_string_literal: true

require_relative "base"

module Unitsdb
  module Commands
    class Search < Base
      desc "search QUERY", "Search for entities containing the given text"
      option :type, type: :string, aliases: "-t",
                    desc: "Entity type to search (units, prefixes, quantities, dimensions, unit_systems)"
      option :id, type: :string, aliases: "-i",
                  desc: "Search for an entity with a specific identifier"
      option :id_type, type: :string,
                       desc: "Filter get_by_id search by identifier type"

      def search(query, options = {})
        dir = options[:dir] || "."
        type = options[:type]
        id = options[:id]
        id_type = options[:id_type]

        begin
          database = load_database(dir)

          if id
            # If --id option is provided, use get_by_id
            entity = database.get_by_id(id: id, type: id_type)

            if entity
              print_entity(entity)
            else
              puts "No entity found with ID: '#{id}'"
            end
            return
          end

          # Otherwise, search by text
          results = database.search(text: query, type: type)

          if results.empty?
            puts "No results found for '#{query}'"
            return
          end

          puts "Found #{results.size} result(s) for '#{query}':"

          results.each do |entity|
            # Determine entity type
            entity_type = if entity.is_a?(Unitsdb::Unit)
                            "Unit"
                          elsif entity.is_a?(Unitsdb::Prefix)
                            "Prefix"
                          elsif entity.is_a?(Unitsdb::Quantity)
                            "Quantity"
                          elsif entity.is_a?(Unitsdb::Dimension)
                            "Dimension"
                          elsif entity.is_a?(Unitsdb::UnitSystem)
                            "UnitSystem"
                          else
                            "Unknown"
                          end

            # Get identifier value if available
            identifier = entity.identifiers&.first&.id || "N/A"

            # Get name based on entity type (different entities represent names differently)
            name = if entity.respond_to?(:names) && entity.names&.any?
                     entity.names.first
                   elsif entity.respond_to?(:name) && entity.name
                     entity.name
                   elsif entity.respond_to?(:short) && entity.short
                     entity.short
                   else
                     "N/A"
                   end

            # Print entity information
            puts "  - #{entity_type}: #{name} (ID: #{identifier})"

            # If entity has a short description, print it
            puts "    Description: #{entity.short}" if entity.respond_to?(:short) && entity.short && entity.short != name

            # Add a blank line for readability
            puts ""
          end
        rescue StandardError => e
          puts "Error searching database: #{e.message}"
          exit(1)
        end
      end

      private

      def print_entity(entity)
        # Determine entity type
        entity_type = if entity.is_a?(Unitsdb::Unit)
                        "Unit"
                      elsif entity.is_a?(Unitsdb::Prefix)
                        "Prefix"
                      elsif entity.is_a?(Unitsdb::Quantity)
                        "Quantity"
                      elsif entity.is_a?(Unitsdb::Dimension)
                        "Dimension"
                      elsif entity.is_a?(Unitsdb::UnitSystem)
                        "UnitSystem"
                      else
                        "Unknown"
                      end

        # Get identifier value if available
        identifier = entity.identifiers&.first&.id || "N/A"

        # Get name based on entity type (different entities represent names differently)
        name = if entity.respond_to?(:names) && entity.names&.any?
                 entity.names.first
               elsif entity.respond_to?(:name) && entity.name
                 entity.name
               elsif entity.respond_to?(:short) && entity.short
                 entity.short
               else
                 "N/A"
               end

        # Print entity information
        puts "Found entity:"
        puts "  - #{entity_type}: #{name} (ID: #{identifier})"

        # If entity has a short description, print it
        puts "    Description: #{entity.short}" if entity.respond_to?(:short) && entity.short && entity.short != name

        # Print all identifiers
        return unless entity.identifiers&.any?

        puts "    Identifiers:"
        entity.identifiers.each do |id|
          puts "      - #{id.id} (Type: #{id.type || "N/A"})"
        end
      end
    end
  end
end
