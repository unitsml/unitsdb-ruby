# frozen_string_literal: true

require "thor"

module Unitsdb
  module Commands
    module Validate
      autoload :Identifiers, "unitsdb/commands/validate/identifiers"
      autoload :QudtReferences, "unitsdb/commands/validate/qudt_references"
      autoload :References, "unitsdb/commands/validate/references"
      autoload :SiReferences, "unitsdb/commands/validate/si_references"
      autoload :UcumReferences, "unitsdb/commands/validate/ucum_references"
    end

    class ValidateCommand < Thor
      desc "references", "Validate that all references exist"
      option :debug_registry, type: :boolean,
                              desc: "Show registry contents for debugging"
      option :database, type: :string, required: true, aliases: "-d",
                        desc: "Path to UnitsDB database (required)"
      option :print_valid, type: :boolean, default: false,
                           desc: "Print valid references too"
      def references
        Commands::Validate::References.new(options).run
      end

      desc "identifiers", "Check for uniqueness of identifier fields"
      option :database, type: :string, required: true, aliases: "-d",
                        desc: "Path to UnitsDB database (required)"

      def identifiers
        Commands::Validate::Identifiers.new(options).run
      end

      desc "si_references",
           "Validate that each SI digital framework reference is unique per entity type"
      option :database, type: :string, required: true, aliases: "-d",
                        desc: "Path to UnitsDB database (required)"

      def si_references
        Commands::Validate::SiReferences.new(options).run
      end

      desc "qudt_references",
           "Validate that each QUDT reference is unique per entity type"
      option :database, type: :string, required: true, aliases: "-d",
                        desc: "Path to UnitsDB database (required)"

      def qudt_references
        Commands::Validate::QudtReferences.new(options).run
      end

      desc "ucum_references",
           "Validate that each UCUM reference is unique per entity type"
      option :database, type: :string, required: true, aliases: "-d",
                        desc: "Path to UnitsDB database (required)"

      def ucum_references
        Commands::Validate::UcumReferences.new(options).run
      end
    end
  end
end
