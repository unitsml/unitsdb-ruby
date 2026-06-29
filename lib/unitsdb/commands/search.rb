# frozen_string_literal: true

module Unitsdb
  module Commands
    class Search < Base
      def run(query)
        type = @options[:type]
        id = @options[:id]
        id_type = @options[:id_type]
        format = @options[:format] || "text"

        database = load_database(@options[:database])

        if id
          lookup_by_id(database, id, id_type, format)
          return
        end

        results = database.search(text: query, type: type)
        if results.empty?
          puts "No results found for '#{query}'"
          return
        end

        print_results(results, query, format)
      rescue Unitsdb::Errors::DatabaseError => e
        raise Unitsdb::Errors::DatabaseLoadError,
              "Failed to load database: #{e.message}"
      rescue StandardError => e
        raise Unitsdb::Errors::CLIRuntimeError, "Search failed: #{e.message}"
      end

      private

      def lookup_by_id(database, id, id_type, format)
        entity = database.get_by_id(id: id, type: id_type)
        if entity.nil?
          puts "No entity found with ID: '#{id}'"
          return
        end

        if %w[json yaml].include?(format.downcase)
          print_serialized(entity, format.downcase)
        else
          EntityPresenter.new(entity).print_details
        end
      end

      def print_results(results, query, format)
        if %w[json yaml].include?(format.downcase)
          temp_db = Database.empty_for_results(results)
          print_serialized(temp_db, format.downcase)
          return
        end

        puts "Found #{results.size} result(s) for '#{query}':"
        results.each { |entity| EntityPresenter.new(entity).print_summary }
      end

      def print_serialized(entity, format)
        puts entity.public_send("to_#{format}")
      end
    end
  end
end
