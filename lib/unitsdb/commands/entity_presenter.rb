# frozen_string_literal: true

module Unitsdb
  module Commands
    # Present a single entity as text for the Get/Search CLI commands.
    # Pulls every displayable field off the typed model — no
    # `respond_to?` feature detection. New entity types extend
    # `TYPE_NAME` and `extras`; nothing else changes.
    class EntityPresenter
      TYPE_NAME = {
        Unitsdb::Unit => "Unit",
        Unitsdb::Prefix => "Prefix",
        Unitsdb::Quantity => "Quantity",
        Unitsdb::Dimension => "Dimension",
        Unitsdb::UnitSystem => "UnitSystem",
      }.freeze

      def initialize(entity)
        @entity = entity
      end

      # Human-readable type label, e.g. "Unit", "Prefix".
      def type_name
        TYPE_NAME[@entity.class] || @entity.class.name.split("::").last
      end

      # Best-effort display name: first localized name value → short → "N/A".
      def display_name
        name = @entity.names.first
        return name.value.to_s if name&.value
        return @entity.short.to_s if @entity.short

        "N/A"
      end

      # Multi-line "details" output for `unitsdb get ID`.
      def print_details
        puts "Entity details:"
        puts "  - Type: #{type_name}"
        puts "  - Name: #{display_name}"
        puts "  - Description: #{@entity.short}" if show_short?
        print_identifiers(header: "  - Identifiers:", item_indent: "      ")
        print_extras
        print_references
      end

      # Single-block summary used by `unitsdb search` per result.
      def print_summary
        puts "  - #{type_name}: #{display_name}"
        print_identifiers(header: "    IDs:", item_indent: "      ")
        puts "    Description: #{@entity.short}" if show_short?
        puts ""
      end

      private

      def show_short?
        @entity.short && @entity.short != display_name
      end

      def print_identifiers(header:, item_indent:)
        identifiers = @entity.identifiers
        if identifiers.empty?
          puts "#{header} None"
          return
        end

        puts header
        identifiers.each do |id|
          puts "#{item_indent}- #{id.id} (Type: #{id.type || 'N/A'})"
        end
      end

      def print_extras
        case @entity
        when Unitsdb::Unit
          print_unit_symbols
        end
      end

      def print_unit_symbols
        return unless @entity.symbols.any?

        puts "  - Symbols:"
        @entity.symbols.each { |s| puts "      - #{s}" }
      end

      def print_references
        return unless @entity.references.any?

        puts "  - References:"
        @entity.references.each do |ref|
          puts "      - #{ref.type}: #{ref.uri}"
        end
      end
    end
  end
end
