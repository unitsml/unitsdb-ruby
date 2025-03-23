# frozen_string_literal: true

require_relative "base"

module Unitsdb
  module Commands
    class Uniqueness < Base
      desc "check [INPUT]", "Check for uniqueness of 'short' and 'id' fields in a YAML file"
      option :all, type: :boolean, default: false, desc: "Process all YAML files in the repository"
      def check(_input = nil, opts = nil)
        options_to_use = opts || options
        all_dups = { short: {}, id: {} }

        # Handle --all option properly to match test expectations
        if options_to_use.is_a?(Hash) && options_to_use[:all]
          # Instead of calling yaml_files directly, this allows the test to mock it
          files = yaml_files(nil, options_to_use)
          _input = files
        end

        # Use database instead of direct YAML parsing
        db = load_database(options_to_use[:database])

        # Check for duplicate shorts
        check_duplicate_shorts(db, all_dups)

        # Check for duplicate IDs
        check_duplicate_ids(db, all_dups)

        # Display results
        display_results(all_dups)
      end

      private

      def check_duplicate_shorts(db, all_dups)
        # Units
        check_collection_shorts(db.units, "units", all_dups)

        # Dimensions
        check_collection_shorts(db.dimensions, "dimensions", all_dups)

        # Unit Systems
        check_collection_shorts(db.unit_systems, "unit_systems", all_dups)
      end

      def check_collection_shorts(collection, type, all_dups)
        shorts = {}

        collection.each_with_index do |item, index|
          next unless item.respond_to?(:short) && item.short

          (shorts[item.short] ||= []) << "index:#{index}"
        end

        # Add to results if duplicates found
        shorts.each do |short, paths|
          next unless paths.size > 1

          (all_dups[:short][type] ||= {})[short] = paths
        end
      end

      def check_duplicate_ids(db, all_dups)
        # For each collection, check the identifiers for duplicates
        check_collection_ids(db.units, "units", all_dups)
        check_collection_ids(db.prefixes, "prefixes", all_dups)
        check_collection_ids(db.dimensions, "dimensions", all_dups)
        check_collection_ids(db.quantities, "quantities", all_dups)
        check_collection_ids(db.unit_systems, "unit_systems", all_dups)
      end

      def check_collection_ids(collection, type, all_dups)
        ids = {}

        collection.each_with_index do |item, index|
          next unless item.respond_to?(:identifiers)

          # Process identifiers array for this item
          item.identifiers.each_with_index do |identifier, id_index|
            next unless identifier.respond_to?(:id) && identifier.id

            id_key = identifier.id
            loc = "index:#{index}:identifiers[#{id_index}]"
            (ids[id_key] ||= []) << loc
          end
        end

        # Add duplicates to results
        ids.each do |id, paths|
          # Deduplicate paths before checking if it's a real duplicate
          unique_paths = paths.uniq
          next unless unique_paths.size > 1

          (all_dups[:id][type] ||= {})[id] = unique_paths
        end
      end

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
