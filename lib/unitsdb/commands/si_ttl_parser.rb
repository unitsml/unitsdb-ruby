# frozen_string_literal: true

require "rdf"
require "rdf/turtle"

module Unitsdb
  module Commands
    # Parser for SI TTL files
    module SiTtlParser
      SI_URI_PREFIX = "http://si-digital-framework.org/SI/"

      module_function

      # Parse TTL files and return RDF graph
      def parse_ttl_files(dir)
        puts "Parsing TTL files in #{dir}..."
        graph = RDF::Graph.new

        Dir.glob(File.join(dir, "*.ttl")).each do |file|
          puts "  Reading #{File.basename(file)}"
          graph.load(file, format: :ttl)
        end

        graph
      end

      # Extract entities from TTL based on entity type
      def extract_entities_from_ttl(entity_type, graph)
        skos = RDF::Vocabulary.new("http://www.w3.org/2004/02/skos/core#")
        si = RDF::Vocabulary.new("http://si-digital-framework.org/SI#")

        namespace_uri = case entity_type
                        when "units" then "http://si-digital-framework.org/SI/units/"
                        when "quantities" then "http://si-digital-framework.org/quantities/"
                        when "prefixes" then "http://si-digital-framework.org/SI/prefixes/"
                        else return []
                        end

        namespace = RDF::Vocabulary.new(namespace_uri)
        entities = extract_base_entities(graph, namespace, skos)
        add_symbols_to_entities(entities, graph, si) if %w[units prefixes].include?(entity_type)
        entities
      end

      # Extract base entities from graph
      def extract_base_entities(graph, namespace, skos)
        entities = []
        processed_uris = {}

        RDF::Query.new({ entity: { skos.prefLabel => :label } })
                  .execute(graph).each do |solution|
          entity_uri = solution.entity.to_s
          next unless entity_uri.start_with?(namespace.to_s)
          next if processed_uris[entity_uri]

          processed_uris[entity_uri] = true

          entity_name = entity_uri.split("/").last
          label = RDF::Query.new({ RDF::URI(entity_uri) => { skos.prefLabel => :value } })
                            .execute(graph).first&.value&.to_s
          alt_label = RDF::Query.new({ RDF::URI(entity_uri) => { skos.altLabel => :value } })
                                .execute(graph).first&.value&.to_s

          entities << {
            uri: entity_uri,
            name: entity_name,
            label: label,
            alt_label: alt_label
          }
        end

        entities
      end

      # Add symbols to entities
      def add_symbols_to_entities(entities, graph, si)
        entities.each do |entity|
          symbol = RDF::Query.new({ RDF::URI(entity[:uri]) => { si.hasSymbol => :value } })
                             .execute(graph).first&.value&.to_s
          entity[:symbol] = symbol if symbol
        end
      end

      # Extract suffix from URI for display
      def extract_identifying_suffix(uri)
        return "" unless uri

        # For display, we need to format as exactly like the original
        # This helps format the comma-separated multi-units correctly
        if uri.include?("/units/")
          # Return units/name format for units (without duplicating "units/")
          "units/#{uri.split("/").last}"
        else
          # Otherwise strip the prefix
          uri.gsub(SI_URI_PREFIX, "")
        end
      end
    end
  end
end
