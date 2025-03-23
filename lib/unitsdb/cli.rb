# frozen_string_literal: true

require "thor"
require_relative "commands/validate"
require_relative "commands/check_si_references"
require_relative "commands/search"
require_relative "commands/get"
require_relative "commands/check_si_units"
require_relative "commands/_modify"

module Unitsdb
  class CLI < Thor
    desc "_modify SUBCOMMAND", "Commands that modify the database"
    subcommand "_modify", Commands::ModifyCommand

    desc "validate SUBCOMMAND", "Validate database files for different conditions"
    subcommand "validate", Commands::ValidateCommand

    desc "check_si_references",
         "Check entities in SI digital framework against entities in the database (original implementation)"
    method_option :entity_type, type: :string, aliases: "-e",
                                desc: "Entity type to check (units, quantities, or prefixes). If not specified, all types are checked"
    method_option :output, type: :string, aliases: "-o",
                           desc: "Output file path for updated YAML file(s)"
    method_option :update, type: :boolean, default: false,
                           desc: "Update references in output file(s)"
    method_option :database, type: :string, required: true, aliases: "-d",
                             desc: "Path to UnitsDB database (required)"

    def check_si_references
      Commands::CheckSiReferences.new.check
    end

    desc "check_si_refs", "Check units in SI digital framework and add missing references (simplified implementation)"
    method_option :entity_type, type: :string, aliases: "-e",
                                desc: "Entity type to check (units, quantities, or prefixes). Defaults to units."
    method_option :output, type: :string, aliases: "-o",
                           desc: "Output file path for updated YAML file"
    method_option :update, type: :boolean, default: false,
                           desc: "Update references in output file"
    method_option :database, type: :string, required: true, aliases: "-d",
                             desc: "Path to UnitsDB database (required)"

    def check_si_refs
      require_relative "commands/check_si_references_simple"
      Commands::CheckSiReferencesSimple.new.check(options)
    end

    desc "search QUERY", "Search for entities in the database"
    method_option :type, type: :string, aliases: "-t",
                         desc: "Entity type to search (units, prefixes, quantities, dimensions, unit_systems)"
    method_option :id, type: :string, aliases: "-i",
                       desc: "Search for an entity with a specific identifier"
    method_option :id_type, type: :string,
                            desc: "Filter get_by_id search by identifier type"
    method_option :format, type: :string, default: "text",
                           desc: "Output format (text, json, yaml)"
    method_option :database, type: :string, required: true, aliases: "-d",
                             desc: "Path to UnitsDB database (required)"

    def search(query)
      Commands::Search.new.search(query, options)
    end

    desc "get ID", "Get detailed information about a specific entity"
    method_option :id_type, type: :string,
                            desc: "Identifier type to filter by"
    method_option :format, type: :string, default: "text",
                           desc: "Output format (text, json, yaml)"
    method_option :database, type: :string, required: true, aliases: "-d",
                             desc: "Path to UnitsDB database (required)"

    def get(id)
      Commands::Get.new.get(id, options)
    end

    desc "check_si_units", "Check that every unit in the SI digital framework has an equivalent in our units.yaml"
    method_option :output, type: :string, aliases: "-o",
                           desc: "Output file path for updated YAML file"
    method_option :database, type: :string, required: true, aliases: "-d",
                             desc: "Path to UnitsDB database (required)"
    method_option :ttl_dir, type: :string, required: true, aliases: "-t",
                            desc: "Path to the directory containing SI digital framework TTL files"

    def check_si_units
      Commands::CheckSiUnits.new.check(options)
    end
  end
end
