# frozen_string_literal: true

require_relative "base"

module Unitsdb
  module Commands
    module Validate
      class Identifiers < Thor::Group
        include Thor::Actions

        class_option :database, type: :string, required: true, aliases: "-d",
                                desc: "Path to UnitsDB database (required)"

        def self.banner
          "unitsdb validate identifiers --database=PATH"
        end

        def validate_identifiers
          require_relative "../base"

          # Create a Base instance to use its helper methods
          base = Unitsdb::Commands::Base.new

          begin
            db = base.send(:load_database, options[:database])
            all_dups = db.validate_uniqueness

            display_results(all_dups)
          rescue Unitsdb::DatabaseError => e
            puts "Error: #{e.message}"
            exit(1)
          end
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
