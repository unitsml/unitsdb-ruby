# frozen_string_literal: true

require "thor"
require_relative "commands/uniqueness"
require_relative "commands/normalize"
require_relative "commands/validate"
require_relative "commands/check_si_references"
require_relative "commands/search"

module Unitsdb
  class CLI < Thor
    desc "check_uniqueness [INPUT]", "Check for uniqueness of 'short' and 'id' fields in a YAML file"
    method_option :all, type: :boolean, default: false, aliases: "-a", desc: "Check all YAML files in the repository"
    method_option :dir, type: :string, default: ".", aliases: "-d", desc: "Directory containing the YAML files"

    def check_uniqueness(input = nil)
      Commands::Uniqueness.new.check(input, options)
    end

    desc "normalize [INPUT] [OUTPUT]", "Normalize a YAML file or all YAML files with --all"
    method_option :sort, type: :boolean, default: true, desc: "Sort keys alphabetically"
    method_option :all, type: :boolean, default: false, aliases: "-a",
                        desc: "Normalize all YAML files in the repository"
    method_option :dir, type: :string, default: ".", aliases: "-d", desc: "Directory containing the YAML files"

    def normalize(input = nil, output = nil)
      Commands::Normalize.new.yaml(input, output, options)
    end

    desc "validate SUBCOMMAND", "Validate YAML files for different conditions"
    subcommand "validate", Commands::ValidateCommand

    desc "check_si_references",
         "Check entities in SI digital framework against entities in the database (original implementation)"
    method_option :entity_type, type: :string, aliases: "-e",
                                desc: "Entity type to check (units, quantities, or prefixes). If not specified, all types are checked"
    method_option :output, type: :string, aliases: "-o",
                           desc: "Output file path for updated YAML file(s)"
    method_option :update, type: :boolean, default: false,
                           desc: "Update references in output file(s)"
    method_option :dir, type: :string, default: ".", aliases: "-d",
                        desc: "Directory containing the YAML files"

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
    method_option :dir, type: :string, default: ".", aliases: "-d",
                        desc: "Directory containing the YAML files"

    def search(query)
      Commands::Search.new.search(query, options)
    end
  end
end
