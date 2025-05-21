# frozen_string_literal: true

require_relative "../../ucum"

module Unitsdb
  module Commands
    module Ucum
      # Parser for UCUM XML files
      module XmlParser
        module_function

        # Parse UCUM XML file and return parsed data
        def parse_ucum_file(file_path)
          puts "Parsing UCUM XML file: #{file_path}..."
          content = File.read(file_path)
          Unitsdb::UcumFile.from_xml(content)
        end

        # Get entities from parsed UCUM data based on entity type
        def get_entities_from_ucum(entity_type, ucum_data)
          case entity_type
          when "prefixes"
            ucum_data.prefixes
          when "units"
            # Combine base-units and units into a single array
            ucum_data.base_units + ucum_data.units
          else
            []
          end
        end
      end
    end
  end
end
