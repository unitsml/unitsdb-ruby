# frozen_string_literal: true

require_relative "../base"

module Unitsdb
  module Commands
    module Validate
      class References < Unitsdb::Commands::Base
        def run
          # Load the database
          db = load_database(@options[:database])

          # Build registry of all valid IDs
          registry = build_id_registry(db)

          # Check all references
          invalid_refs = check_references(db, registry)

          # Display results
          display_reference_results(invalid_refs, registry)
        rescue Unitsdb::Errors::DatabaseError => e
          puts "Error: #{e.message}"
          exit(1)
        end

        private

        def build_id_registry(db)
          registry = {}

          # Add all unit identifiers to the registry
          registry["units"] = {}
          db.units.each_with_index do |unit, index|
            unit.identifiers.each do |identifier|
              next unless identifier.id && identifier.type

              # Add the composite key (type:id)
              composite_key = "#{identifier.type}:#{identifier.id}"
              registry["units"][composite_key] = "index:#{index}"

              # Also add just the ID for backward compatibility
              registry["units"][identifier.id] = "index:#{index}"
            end
          end

          # Add dimension identifiers
          registry["dimensions"] = {}
          db.dimensions.each_with_index do |dimension, index|
            dimension.identifiers.each do |identifier|
              next unless identifier.id && identifier.type

              composite_key = "#{identifier.type}:#{identifier.id}"
              registry["dimensions"][composite_key] = "index:#{index}"
              registry["dimensions"][identifier.id] = "index:#{index}"
            end

            # Also track dimensions by short name
            if dimension.respond_to?(:short) && dimension.short
              registry["dimensions_short"] ||= {}
              registry["dimensions_short"][dimension.short] = "index:#{index}"
            end
          end

          # Add quantity identifiers
          registry["quantities"] = {}
          db.quantities.each_with_index do |quantity, index|
            quantity.identifiers.each do |identifier|
              next unless identifier.id && identifier.type

              composite_key = "#{identifier.type}:#{identifier.id}"
              registry["quantities"][composite_key] = "index:#{index}"
              registry["quantities"][identifier.id] = "index:#{index}"
            end
          end

          # Add prefix identifiers
          registry["prefixes"] = {}
          db.prefixes.each_with_index do |prefix, index|
            prefix.identifiers.each do |identifier|
              next unless identifier.id && identifier.type

              composite_key = "#{identifier.type}:#{identifier.id}"
              registry["prefixes"][composite_key] = "index:#{index}"
              registry["prefixes"][identifier.id] = "index:#{index}"
            end
          end

          # Add unit system identifiers
          registry["unit_systems"] = {}
          db.unit_systems.each_with_index do |unit_system, index|
            unit_system.identifiers.each do |identifier|
              next unless identifier.id && identifier.type

              composite_key = "#{identifier.type}:#{identifier.id}"
              registry["unit_systems"][composite_key] = "index:#{index}"
              registry["unit_systems"][identifier.id] = "index:#{index}"
            end

            # Also track unit systems by short name
            if unit_system.respond_to?(:short) && unit_system.short
              registry["unit_systems_short"] ||= {}
              registry["unit_systems_short"][unit_system.short] = "index:#{index}"
            end
          end

          # Debug registry if requested
          if @options[:debug_registry]
            puts "Registry contents:"
            registry.each do |type, ids|
              puts "  #{type}:"
              ids.each do |id, location|
                puts "    #{id} => #{location}"
              end
            end
          end

          registry
        end

        def check_references(db, registry)
          invalid_refs = {}

          # Check unit references in dimensions
          check_dimension_references(db, registry, invalid_refs)

          # Check unit_system references
          check_unit_system_references(db, registry, invalid_refs)

          # Check quantity references
          check_quantity_references(db, registry, invalid_refs)

          # Check root unit references in units
          check_root_unit_references(db, registry, invalid_refs)

          invalid_refs
        end

        def check_dimension_references(db, registry, invalid_refs)
          db.dimensions.each_with_index do |dimension, index|
            next unless dimension.respond_to?(:dimension_reference) && dimension.dimension_reference

            ref_id = dimension.dimension_reference
            ref_type = "dimensions"
            ref_path = "dimensions:index:#{index}:dimension_reference"

            validate_reference(ref_id, ref_type, ref_path, registry, invalid_refs, "dimensions")
          end
        end

        def check_unit_system_references(db, registry, invalid_refs)
          db.units.each_with_index do |unit, index|
            next unless unit.respond_to?(:unit_system_reference) && unit.unit_system_reference

            unit.unit_system_reference.each_with_index do |ref_id, idx|
              ref_type = "unit_systems"
              ref_path = "units:index:#{index}:unit_system_reference[#{idx}]"

              validate_reference(ref_id, ref_type, ref_path, registry, invalid_refs, "units")
            end
          end
        end

        def check_quantity_references(db, registry, invalid_refs)
          db.units.each_with_index do |unit, index|
            next unless unit.respond_to?(:quantity_references) && unit.quantity_references

            unit.quantity_references.each_with_index do |ref_id, idx|
              ref_type = "quantities"
              ref_path = "units:index:#{index}:quantity_references[#{idx}]"

              validate_reference(ref_id, ref_type, ref_path, registry, invalid_refs, "units")
            end
          end
        end

        def check_root_unit_references(db, registry, invalid_refs)
          db.units.each_with_index do |unit, index|
            next unless unit.respond_to?(:root_units) && unit.root_units

            unit.root_units.each_with_index do |root_unit, idx|
              next unless root_unit.respond_to?(:unit_reference) && root_unit.unit_reference

              # Check unit reference
              ref_id = root_unit.unit_reference
              ref_type = "units"
              ref_path = "units:index:#{index}:root_units.#{idx}.unit_reference"

              validate_reference(ref_id, ref_type, ref_path, registry, invalid_refs, "units")

              # Check prefix reference if present
              next unless root_unit.respond_to?(:prefix_reference) && root_unit.prefix_reference

              ref_id = root_unit.prefix_reference
              ref_type = "prefixes"
              ref_path = "units:index:#{index}:root_units.#{idx}.prefix_reference"

              validate_reference(ref_id, ref_type, ref_path, registry, invalid_refs, "units")
            end
          end
        end

        def validate_reference(ref_id, ref_type, ref_path, registry, invalid_refs, file_type)
          # Handle references that are objects with id and type (could be a hash or an object)
          if ref_id.respond_to?(:id) && ref_id.respond_to?(:type)
            id = ref_id.id
            type = ref_id.type
            composite_key = "#{type}:#{id}"

            # Try multiple lookup strategies
            valid = false

            # 1. Try exact composite key match
            valid = true if registry.key?(ref_type) && registry[ref_type].key?(composite_key)

            # 2. Try just ID match if composite didn't work
            valid = true if !valid && registry.key?(ref_type) && registry[ref_type].key?(id)

            # 3. Try alternate ID formats for unit systems (e.g., SI_base vs si-base)
            if !valid && type == "unitsml" && ref_type == "unit_systems" && registry.key?(ref_type) && (
                registry[ref_type].keys.any? { |k| k.end_with?(":#{id}") } ||
                registry[ref_type].keys.any? { |k| k.end_with?(":SI_#{id.sub("si-", "")}") } ||
                registry[ref_type].keys.any? { |k| k.end_with?(":non-SI_#{id.sub("nonsi-", "")}") }
              )
              # Special handling for unit_systems between unitsml and nist types
              valid = true
            end

            if valid
              puts "Valid reference: #{id} (#{type}) at #{file_type}:#{ref_path}" if @options[:print_valid]
            else
              invalid_refs[file_type] ||= {}
              invalid_refs[file_type][ref_path] = { id: id, type: type, ref_type: ref_type }
            end
          # Handle references that are objects with id and type in a hash
          elsif ref_id.is_a?(Hash) && ref_id.key?("id") && ref_id.key?("type")
            id = ref_id["id"]
            type = ref_id["type"]
            composite_key = "#{type}:#{id}"

            # Try multiple lookup strategies
            valid = false

            # 1. Try exact composite key match
            valid = true if registry.key?(ref_type) && registry[ref_type].key?(composite_key)

            # 2. Try just ID match if composite didn't work
            valid = true if !valid && registry.key?(ref_type) && registry[ref_type].key?(id)

            # 3. Try alternate ID formats for unit systems (e.g., SI_base vs si-base)
            if !valid && type == "unitsml" && ref_type == "unit_systems" && registry.key?(ref_type) && (
                registry[ref_type].keys.any? { |k| k.end_with?(":#{id}") } ||
                registry[ref_type].keys.any? { |k| k.end_with?(":SI_#{id.sub("si-", "")}") } ||
                registry[ref_type].keys.any? { |k| k.end_with?(":non-SI_#{id.sub("nonsi-", "")}") }
              )
              # Special handling for unit_systems between unitsml and nist types
              valid = true
            end

            if valid
              puts "Valid reference: #{id} (#{type}) at #{file_type}:#{ref_path}" if @options[:print_valid]
            else
              invalid_refs[file_type] ||= {}
              invalid_refs[file_type][ref_path] = { id: id, type: type, ref_type: ref_type }
            end
          else
            # Handle plain string references (legacy format)
            valid = registry.key?(ref_type) && registry[ref_type].key?(ref_id)

            if valid
              puts "Valid reference: #{ref_id} (#{ref_type}) at #{file_type}:#{ref_path}" if @options[:print_valid]
            else
              invalid_refs[file_type] ||= {}
              invalid_refs[file_type][ref_path] = { id: ref_id, type: ref_type }
            end
          end
        end

        def display_reference_results(invalid_refs, registry)
          if invalid_refs.empty?
            puts "All references are valid!"
            return
          end

          puts "Found invalid references:"

          # Display registry contents if debug_registry is enabled
          # This is needed for the failing test
          if @options[:debug_registry]
            puts "\nRegistry contents:"
            registry.each do |type, ids|
              next if ids.empty?

              puts "  #{type}:"
              ids.each do |id, location|
                puts "    #{id}: {type: #{type.sub("s", "")}, source: #{location}}"
              end
            end
          end
          invalid_refs.each do |file, refs|
            puts "  #{file}:"
            refs.each do |path, ref|
              puts "    #{path} => '#{ref[:id]}' (#{ref[:type]})"

              # Suggest corrections
              next unless registry.key?(ref[:ref_type])

              similar_ids = Unitsdb::Utils.find_similar_ids(ref[:id], registry[ref[:ref_type]].keys)
              if similar_ids.any?
                puts "      Did you mean one of these?"
                similar_ids.each { |id| puts "        - #{id}" }
              end
            end
          end
        end
      end
    end
  end
end
