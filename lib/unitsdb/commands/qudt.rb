# frozen_string_literal: true

require "thor"

module Unitsdb
  module Commands
    module Qudt
      autoload :Check, "unitsdb/commands/qudt/check"
      autoload :Formatter, "unitsdb/commands/qudt/formatter"
      autoload :TtlParser, "unitsdb/commands/qudt/ttl_parser"
      autoload :Update, "unitsdb/commands/qudt/update"
      autoload :Updater, "unitsdb/commands/qudt/updater"
    end

    class QudtCommand < Thor
      desc "check", "Check QUDT references in UnitsDB"
      option :entity_type, type: :string, aliases: "-e",
                           desc: "Entity type to check (units, quantities, dimensions, unit_systems). If not specified, all types are checked"
      option :ttl_dir, type: :string, aliases: "-t",
                       desc: "Path to directory containing QUDT TTL files. If not specified, vocabularies will be downloaded from online sources"
      option :output_updated_database, type: :string, aliases: "-o",
                                       desc: "Directory path to write updated YAML files with added QUDT references"
      option :direction, type: :string, default: "both", aliases: "-r",
                         desc: "Direction to check: 'to_qudt' (UnitsDB→QUDT), 'from_qudt' (QUDT→UnitsDB), or 'both'"
      option :include_potential_matches, type: :boolean, default: false, aliases: "-p",
                                         desc: "Include potential matches when updating references (default: false)"
      option :database, type: :string, required: true, aliases: "-d",
                        desc: "Path to UnitsDB database (required)"
      def check
        Qudt::Check.new(options).run
      end

      desc "update", "Update UnitsDB with QUDT references"
      option :entity_type, type: :string, aliases: "-e",
                           desc: "Entity type to update (units, quantities, dimensions, unit_systems). If not specified, all types are updated"
      option :ttl_dir, type: :string, aliases: "-t",
                       desc: "Path to directory containing QUDT TTL files. If not specified, vocabularies will be downloaded from online sources"
      option :output_dir, type: :string, aliases: "-o",
                          desc: "Directory path to write updated YAML files (defaults to database path)"
      option :include_potential_matches, type: :boolean, default: false, aliases: "-p",
                                         desc: "Include potential matches when updating references (default: false)"
      option :database, type: :string, required: true, aliases: "-d",
                        desc: "Path to UnitsDB database (required)"
      def update
        Qudt::Update.new(options).run
      end
    end
  end
end
