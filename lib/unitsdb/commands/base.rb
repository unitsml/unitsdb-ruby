# frozen_string_literal: true

require "yaml"
require "fileutils"

module Unitsdb
  module Commands
    class Base
      def initialize(options = {})
        @options = options
        puts "Database directory path: #{@options[:database]}" if @options[:database]
      end

      protected

      def load_database(path = nil)
        path ||= @options[:database]
        raise Unitsdb::Errors::DatabaseError, "Database path not specified" unless path

        Unitsdb::Database.from_db(path)
      rescue StandardError => e
        raise Unitsdb::Errors::DatabaseError, "Failed to load database: #{e.message}"
      end
    end
  end
end
