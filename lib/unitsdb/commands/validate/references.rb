# frozen_string_literal: true

module Unitsdb
  module Commands
    module Validate
      # `unitsdb validate references`. Thin presenter around
      # Database::ReferenceValidator — owns output formatting only.
      class References < Unitsdb::Commands::Base
        def run
          db = load_database(@options[:database])
          result = Unitsdb::Database::ReferenceValidator.new(db).validate
          display_result(result.invalid)
        rescue Unitsdb::Errors::DatabaseError => e
          raise Unitsdb::Errors::ValidationError,
                "Failed to validate references: #{e.message}"
        end

        private

        def display_result(invalid_refs)
          if invalid_refs.empty?
            puts "All references are valid!"
            return
          end

          puts "Found invalid references:"
          invalid_refs.each do |file, refs|
            puts "  #{file}:"
            refs.each do |path, ref|
              puts "    #{path} => '#{ref[:id]}' (#{ref[:type]})"
            end
          end
        end
      end
    end
  end
end
