# frozen_string_literal: true

require "thor"

module Unitsdb
  module Commands
    class UcumCommand < Thor
      desc "check", "Check UCUM references in UnitsDB"
      option :entity_type, type: :string, aliases: "-e",
                           desc: "Entity type to check (units, prefixes). If not specified, all types are checked"
      option :ucum_file, type: :string, required: true, aliases: "-u",
                         desc: "Path to the UCUM essence XML file"
      option :output_updated_database, type: :string, aliases: "-o",
                                       desc: "Directory path to write updated YAML files with added UCUM references"
      option :direction, type: :string, default: "both", aliases: "-r",
                         desc: "Direction to check: 'to_ucum' (UnitsDB→UCUM), 'from_ucum' (UCUM→UnitsDB), or 'both'"
      option :include_potential_matches, type: :boolean, default: false, aliases: "-p",
                                         desc: "Include potential matches when updating references (default: false)"
      option :database, type: :string, required: true, aliases: "-d",
                        desc: "Path to UnitsDB database (required)"
      def check
        require_relative "ucum/check"
        Ucum::Check.new(options).run
      end

      desc "update", "Update UnitsDB with UCUM references"
      option :entity_type, type: :string, aliases: "-e",
                           desc: "Entity type to update (units, prefixes). If not specified, all types are updated"
      option :ucum_file, type: :string, required: true, aliases: "-u",
                         desc: "Path to the UCUM essence XML file"
      option :output_dir, type: :string, aliases: "-o",
                          desc: "Directory path to write updated YAML files (defaults to database path)"
      option :include_potential_matches, type: :boolean, default: false, aliases: "-p",
                                         desc: "Include potential matches when updating references (default: false)"
      option :database, type: :string, required: true, aliases: "-d",
                        desc: "Path to UnitsDB database (required)"
      def update
        require_relative "ucum/update"
        Ucum::Update.new(options).run
      end
    end
  end
end
