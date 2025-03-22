# frozen_string_literal: true

require_relative "base"

module Unitsdb
  module Commands
    class Search < Base
      desc "text QUERY", "Search for entities containing the given text"
      option :type, type: :string, aliases: "-t",
                    desc: "Entity type to search (units, prefixes, quantities, dimensions, unit_systems)"

      def text(query, options = {})
        dir = options[:dir] || "."
        type = options[:type]

        begin
          database = load_database(dir)
          results = database.search_text(query, type: type)

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
    end
  end
end
