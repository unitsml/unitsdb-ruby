# frozen_string_literal: true

require_relative "../base"

module Unitsdb
  module Commands
    module Validate
      class Identifiers < Unitsdb::Commands::Base
        def run
          db = load_database
          all_dups = db.validate_uniqueness

          display_results(all_dups)
        rescue Unitsdb::Errors::DatabaseError => e
          puts "Error: #{e.message}"
          exit(1)
        end

        private

        def display_results(all_dups)
          %i[short id].each do |type|
            dups = all_dups[type]
            if dups.empty?
              puts "No duplicate '#{type}' fields found."
              next
            end

            puts "\nFound duplicate '#{type}' fields:"
            dups.each do |file, items|
              puts "  #{file}:"
              items.each do |val, paths|
                puts "    '#{val}':"
                paths.each { |p| puts "      - #{p}" }
              end
            end
          end
        end
      end
    end
  end
end
