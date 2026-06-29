# frozen_string_literal: true

module Unitsdb
  module Commands
    class Get < Base
      def get(id)
        id_type = @options[:id_type]
        format = @options[:format] || "text"

        database = load_database(@options[:database])
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
      rescue Unitsdb::Errors::DatabaseError => e
        raise Unitsdb::Errors::DatabaseLoadError,
              "Failed to load database: #{e.message}"
      rescue StandardError => e
        raise Unitsdb::Errors::CLIRuntimeError, "Get failed: #{e.message}"
      end

      private

      def print_serialized(entity, format)
        puts entity.public_send("to_#{format}")
      end
    end
  end
end
