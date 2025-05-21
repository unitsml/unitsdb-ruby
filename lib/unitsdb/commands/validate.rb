# frozen_string_literal: true

require "thor"

module Unitsdb
  module Commands
    class ValidateCommand < Thor
      desc "references", "Validate that all references exist"
      option :debug_registry, type: :boolean, desc: "Show registry contents for debugging"
      option :database, type: :string, required: true, aliases: "-d",
                        desc: "Path to UnitsDB database (required)"
      option :print_valid, type: :boolean, default: false, desc: "Print valid references too"
      def references
        require_relative "validate/references"

        Commands::Validate::References.new(options).run
      end

      desc "identifiers", "Check for uniqueness of identifier fields"
      option :database, type: :string, required: true, aliases: "-d",
                        desc: "Path to UnitsDB database (required)"

      def identifiers
        require_relative "validate/identifiers"

        Commands::Validate::Identifiers.new(options).run
      end

      desc "si_references", "Validate that each SI digital framework reference is unique per entity type"
      option :database, type: :string, required: true, aliases: "-d",
                        desc: "Path to UnitsDB database (required)"

      def si_references
        require_relative "validate/si_references"

        Commands::Validate::SiReferences.new(options).run
      end
    end
  end
end
