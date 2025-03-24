# frozen_string_literal: true

require "thor"
require_relative "commands/validate"
require_relative "commands/_modify"

module Unitsdb
  class CLI < Thor
    # Fix Thor deprecation warning
    def self.exit_on_failure?
      true
    end

    desc "_modify SUBCOMMAND", "Commands that modify the database"
    subcommand "_modify", Commands::ModifyCommand

    desc "validate SUBCOMMAND", "Validate database files for different conditions"
    subcommand "validate", Commands::ValidateCommand

    desc "search QUERY", "Search for entities containing the given text"
    option :type, type: :string, aliases: "-t",
                  desc: "Entity type to search (units, prefixes, quantities, dimensions, unit_systems)"
    option :id, type: :string, aliases: "-i",
                desc: "Search for an entity with a specific identifier"
    option :id_type, type: :string,
                     desc: "Filter get_by_id search by identifier type"
    option :format, type: :string, default: "text",
                    desc: "Output format (text, json, yaml)"
    option :database, type: :string, required: true, aliases: "-d",
                      desc: "Path to UnitsDB database (required)"

    def search(query)
      require_relative "commands/search"
      Commands::Search.new(options).run(query)
    end

    desc "get ID", "Get detailed information about an entity by ID"
    option :id_type, type: :string,
                     desc: "Filter by identifier type"
    option :format, type: :string, default: "text",
                    desc: "Output format (text, json, yaml)"
    option :database, type: :string, required: true, aliases: "-d",
                      desc: "Path to UnitsDB database (required)"
    def get(id)
      require_relative "commands/get"
      Commands::Get.new(options).get(id)
    end

    desc "check_si", "Check entities in SI digital framework against UnitsDB content"
    option :entity_type, type: :string, aliases: "-e",
                         desc: "Entity type to check (units, quantities, or prefixes). If not specified, all types are checked"
    option :ttl_dir, type: :string, required: true, aliases: "-t",
                     desc: "Path to the directory containing SI digital framework TTL files"
    option :output_updated_database, type: :string, aliases: "-o",
                                     desc: "Directory path to write updated YAML files with added SI references"
    option :direction, type: :string, default: "both", aliases: "-r",
                       desc: "Direction to check: 'to_si' (UnitsDB→TTL), 'from_si' (TTL→UnitsDB), or 'both'"
    option :database, type: :string, required: true, aliases: "-d",
                      desc: "Path to UnitsDB database (required)"
    def check_si
      require_relative "commands/check_si"
      Commands::CheckSi.new(options).run
    end

    desc "check_si_references", "Check and update SI digital framework references in UnitsDB"
    option :entity_type, type: :string, aliases: "-e",
                         desc: "Entity type to check (units, quantities, or prefixes). If not specified, all types are checked"
    option :ttl_dir, type: :string, required: true, aliases: "-t",
                     desc: "Path to the directory containing SI digital framework TTL files"
    option :output_updated_database, type: :string, aliases: "-o",
                                     desc: "Directory path to write updated YAML files with added SI references"
    option :direction, type: :string, default: "both", aliases: "-r",
                       desc: "Direction to check: 'to_si' (UnitsDB→TTL), 'from_si' (TTL→UnitsDB), or 'both'"
    option :database, type: :string, required: true, aliases: "-d",
                      desc: "Path to UnitsDB database (required)"

    def check_si_references
      require_relative "commands/check_si_references"
      Commands::CheckSiReferences.new(options).run
    end
  end
end
