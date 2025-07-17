# frozen_string_literal: true

require "net/http"
require "uri"
require "set"
require "rdf"
require "rdf/turtle"
require_relative "../../qudt"

module Unitsdb
  module Commands
    module Qudt
      class TtlParser
        # QUDT 3.1.2 vocabulary URLs
        QUDT_VOCABULARIES = {
          units: "http://qudt.org/3.1.2/vocab/unit",
          quantitykinds: "http://qudt.org/3.1.2/vocab/quantitykind",
          dimensionvectors: "http://qudt.org/3.1.2/vocab/dimensionvector",
          sou: "http://qudt.org/3.1.2/vocab/sou",
          prefixes: "http://qudt.org/3.1.2/vocab/prefix",
        }.freeze

        # QUDT predicates
        QUDT_PREDICATES = {
          label: RDF::URI("http://www.w3.org/2000/01/rdf-schema#label"),
          symbol: RDF::URI("http://qudt.org/schema/qudt/symbol"),
          has_quantity_kind: RDF::URI("http://qudt.org/schema/qudt/hasQuantityKind"),
          has_dimension_vector: RDF::URI("http://qudt.org/schema/qudt/hasDimensionVector"),
          conversion_multiplier: RDF::URI("http://qudt.org/schema/qudt/conversionMultiplier"),
          conversion_offset: RDF::URI("http://qudt.org/schema/qudt/conversionOffset"),
          description: RDF::URI("http://purl.org/dc/elements/1.1/description"),
          abbreviation: RDF::URI("http://qudt.org/schema/qudt/abbreviation"),
          si_exact_match: RDF::URI("http://qudt.org/schema/qudt/siExactMatch"),
          dimension_exponent_for_length: RDF::URI("http://qudt.org/schema/qudt/dimensionExponentForLength"),
          dimension_exponent_for_mass: RDF::URI("http://qudt.org/schema/qudt/dimensionExponentForMass"),
          dimension_exponent_for_time: RDF::URI("http://qudt.org/schema/qudt/dimensionExponentForTime"),
          dimension_exponent_for_electric_current: RDF::URI("http://qudt.org/schema/qudt/dimensionExponentForElectricCurrent"),
          dimension_exponent_for_thermodynamic_temperature: RDF::URI("http://qudt.org/schema/qudt/dimensionExponentForThermodynamicTemperature"),
          dimension_exponent_for_amount_of_substance: RDF::URI("http://qudt.org/schema/qudt/dimensionExponentForAmountOfSubstance"),
          dimension_exponent_for_luminous_intensity: RDF::URI("http://qudt.org/schema/qudt/dimensionExponentForLuminousIntensity"),
          prefix_multiplier: RDF::URI("http://qudt.org/schema/qudt/prefixMultiplier"),
          prefix_multiplier_sn: RDF::URI("http://qudt.org/schema/qudt/prefixMultiplierSN"),
          ucum_code: RDF::URI("http://qudt.org/schema/qudt/ucumCode"),
          rdf_type: RDF::URI("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"),
          dc_description: RDF::URI("http://purl.org/dc/terms/description"),
        }.freeze

        class << self
          # Parse QUDT vocabularies from TTL files or URLs
          def parse_qudt_vocabularies(source_type: :url, ttl_dir: nil)
            vocabularies = QudtVocabularies.new

            QUDT_VOCABULARIES.each do |vocab_type, url|
              puts "Parsing #{vocab_type} vocabulary..."

              ttl_content = if source_type == :file && ttl_dir
                              read_ttl_file(ttl_dir, vocab_type)
                            else
                              download_ttl_content(url)
                            end

              graph = parse_ttl_content(ttl_content)
              entities = extract_entities(graph, vocab_type, url)

              case vocab_type
              when :units
                vocabularies.units = entities
              when :quantitykinds
                vocabularies.quantity_kinds = entities
              when :dimensionvectors
                vocabularies.dimension_vectors = entities
              when :sou
                vocabularies.systems_of_units = entities
              when :prefixes
                vocabularies.prefixes = entities
              end

              puts "Found #{entities.size} #{vocab_type}"
            end

            vocabularies
          end

          # Get entities from vocabularies by type
          def get_entities_from_qudt(entity_type, vocabularies)
            case entity_type
            when "units"
              vocabularies.units
            when "quantities"
              vocabularies.quantity_kinds
            when "dimensions"
              vocabularies.dimension_vectors
            when "unit_systems"
              vocabularies.systems_of_units
            when "prefixes"
              vocabularies.prefixes
            else
              []
            end
          end

          private

          # Read TTL file from local directory
          def read_ttl_file(ttl_dir, vocab_type)
            # Map vocabulary types to actual filenames
            filename_map = {
              units: "unit.ttl",
              quantitykinds: "quantitykind.ttl",
              dimensionvectors: "dimensionvector.ttl",
              sou: "sou.ttl",
              prefixes: "prefix.ttl",
            }

            filename = filename_map[vocab_type] || "#{vocab_type}.ttl"
            file_path = File.join(ttl_dir, filename)

            unless File.exist?(file_path)
              raise "TTL file not found: #{file_path}"
            end

            File.read(file_path)
          end

          # Download TTL content from URL
          def download_ttl_content(url)
            uri = URI(url)
            max_redirects = 5
            redirects = 0

            loop do
              Net::HTTP.start(uri.host, uri.port,
                              use_ssl: uri.scheme == "https") do |http|
                request = Net::HTTP::Get.new(uri)
                request["Accept"] = "text/turtle"

                response = http.request(request)

                case response.code
                when "200"
                  return response.body
                when "301", "302", "303", "307", "308"
                  redirects += 1
                  if redirects > max_redirects
                    raise "Too many redirects for #{url}"
                  end

                  location = response["location"]
                  if location.nil?
                    raise "Redirect response missing location header for #{url}"
                  end

                  uri = URI(location)
                  next
                else
                  raise "Failed to download #{url}: #{response.code} #{response.message}"
                end
              end
            end
          end

          # Parse TTL content into RDF graph
          def parse_ttl_content(ttl_content)
            graph = RDF::Graph.new
            RDF::Turtle::Reader.new(ttl_content) do |reader|
              reader.each_statement do |statement|
                graph << statement
              end
            end
            graph
          end

          # Extract entities from RDF graph
          def extract_entities(graph, vocab_type, base_url)
            entities = []

            # Find all subjects that are instances of the vocabulary type
            subjects = find_vocabulary_subjects(graph, vocab_type, base_url)

            subjects.each do |subject|
              entity = create_entity(graph, subject, vocab_type)
              entities << entity if entity
            end

            entities
          end

          # Find subjects that belong to the vocabulary
          def find_vocabulary_subjects(graph, _vocab_type, base_url)
            subjects = Set.new

            # Get all subjects that have properties from this vocabulary
            graph.each_statement do |statement|
              subject_uri = statement.subject.to_s

              # Check if subject URI starts with the vocabulary base URL
              if subject_uri.start_with?(base_url.sub("/3.1.2/vocab/",
                                                      "/vocab/"))
                subjects << statement.subject
              end
            end

            subjects.to_a
          end

          # Create entity object from RDF data
          def create_entity(graph, subject, vocab_type)
            case vocab_type
            when :units
              create_unit(graph, subject)
            when :quantitykinds
              create_quantity_kind(graph, subject)
            when :dimensionvectors
              create_dimension_vector(graph, subject)
            when :sou
              create_system_of_units(graph, subject)
            when :prefixes
              create_prefix(graph, subject)
            end
          end

          # Create QudtUnit from RDF data
          def create_unit(graph, subject)
            unit = QudtUnit.new
            unit.uri = subject.to_s

            graph.query([subject, nil, nil]) do |statement|
              predicate = statement.predicate
              object = statement.object

              case predicate
              when QUDT_PREDICATES[:label]
                unit.label = object.to_s
              when QUDT_PREDICATES[:symbol]
                unit.symbol = object.to_s
              when QUDT_PREDICATES[:has_quantity_kind]
                unit.has_quantity_kind = object.to_s
              when QUDT_PREDICATES[:has_dimension_vector]
                unit.has_dimension_vector = object.to_s
              when QUDT_PREDICATES[:conversion_multiplier]
                unit.conversion_multiplier = convert_to_float(object)
              when QUDT_PREDICATES[:conversion_offset]
                unit.conversion_offset = convert_to_float(object)
              when QUDT_PREDICATES[:description]
                unit.description = object.to_s
              when QUDT_PREDICATES[:si_exact_match]
                unit.si_exact_match = object.to_s
              end
            end

            unit
          end

          # Create QudtQuantityKind from RDF data
          def create_quantity_kind(graph, subject)
            quantity_kind = QudtQuantityKind.new
            quantity_kind.uri = subject.to_s

            graph.query([subject, nil, nil]) do |statement|
              predicate = statement.predicate
              object = statement.object

              case predicate
              when QUDT_PREDICATES[:label]
                quantity_kind.label = object.to_s
              when QUDT_PREDICATES[:symbol]
                quantity_kind.symbol = object.to_s
              when QUDT_PREDICATES[:has_dimension_vector]
                quantity_kind.has_dimension_vector = object.to_s
              when QUDT_PREDICATES[:description]
                quantity_kind.description = object.to_s
              when QUDT_PREDICATES[:si_exact_match]
                quantity_kind.si_exact_match = object.to_s
              end
            end

            quantity_kind
          end

          # Create QudtDimensionVector from RDF data
          def create_dimension_vector(graph, subject)
            dimension_vector = QudtDimensionVector.new
            dimension_vector.uri = subject.to_s

            graph.query([subject, nil, nil]) do |statement|
              predicate = statement.predicate
              object = statement.object

              case predicate
              when QUDT_PREDICATES[:label]
                dimension_vector.label = object.to_s
              when QUDT_PREDICATES[:description]
                dimension_vector.description = object.to_s
              when QUDT_PREDICATES[:dimension_exponent_for_length]
                dimension_vector.dimension_exponent_for_length = convert_to_integer(object)
              when QUDT_PREDICATES[:dimension_exponent_for_mass]
                dimension_vector.dimension_exponent_for_mass = convert_to_integer(object)
              when QUDT_PREDICATES[:dimension_exponent_for_time]
                dimension_vector.dimension_exponent_for_time = convert_to_integer(object)
              when QUDT_PREDICATES[:dimension_exponent_for_electric_current]
                dimension_vector.dimension_exponent_for_electric_current = convert_to_integer(object)
              when QUDT_PREDICATES[:dimension_exponent_for_thermodynamic_temperature]
                dimension_vector.dimension_exponent_for_thermodynamic_temperature = convert_to_integer(object)
              when QUDT_PREDICATES[:dimension_exponent_for_amount_of_substance]
                dimension_vector.dimension_exponent_for_amount_of_substance = convert_to_integer(object)
              when QUDT_PREDICATES[:dimension_exponent_for_luminous_intensity]
                dimension_vector.dimension_exponent_for_luminous_intensity = convert_to_integer(object)
              end
            end

            dimension_vector
          end

          # Create QudtSystemOfUnits from RDF data
          def create_system_of_units(graph, subject)
            system = QudtSystemOfUnits.new
            system.uri = subject.to_s

            graph.query([subject, nil, nil]) do |statement|
              predicate = statement.predicate
              object = statement.object

              case predicate
              when QUDT_PREDICATES[:label]
                system.label = object.to_s
              when QUDT_PREDICATES[:abbreviation]
                system.abbreviation = object.to_s
              when QUDT_PREDICATES[:description]
                system.description = object.to_s
              end
            end

            system
          end

          # Create QudtPrefix from RDF data
          def create_prefix(graph, subject)
            prefix = QudtPrefix.new
            prefix.uri = subject.to_s

            # Determine prefix type from RDF type
            graph.query([subject, QUDT_PREDICATES[:rdf_type],
                         nil]) do |statement|
              type_uri = statement.object.to_s
              if type_uri.include?("DecimalPrefix")
                prefix.prefix_type = "DecimalPrefix"
              elsif type_uri.include?("BinaryPrefix")
                prefix.prefix_type = "BinaryPrefix"
              end
            end

            graph.query([subject, nil, nil]) do |statement|
              predicate = statement.predicate
              object = statement.object

              case predicate
              when QUDT_PREDICATES[:label]
                prefix.label = object.to_s
              when QUDT_PREDICATES[:symbol]
                prefix.symbol = object.to_s
              when QUDT_PREDICATES[:prefix_multiplier]
                prefix.prefix_multiplier = convert_to_float(object)
              when QUDT_PREDICATES[:prefix_multiplier_sn]
                prefix.prefix_multiplier_sn = object.to_s
              when QUDT_PREDICATES[:ucum_code]
                prefix.ucum_code = object.to_s
              when QUDT_PREDICATES[:si_exact_match]
                prefix.si_exact_match = object.to_s
              when QUDT_PREDICATES[:description], QUDT_PREDICATES[:dc_description]
                prefix.description = object.to_s
              end
            end

            prefix
          end

          # Convert RDF object to float, handling RDF::Literal objects
          def convert_to_float(object)
            case object
            when RDF::Literal
              object.object.to_f
            else
              object.to_s.to_f
            end
          rescue StandardError
            0.0
          end

          # Convert RDF object to integer, handling RDF::Literal objects
          def convert_to_integer(object)
            case object
            when RDF::Literal
              object.object.to_i
            else
              object.to_s.to_i
            end
          rescue StandardError
            0
          end
        end
      end
    end
  end
end
