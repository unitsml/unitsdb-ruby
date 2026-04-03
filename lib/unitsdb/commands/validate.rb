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
      # Inherit trace option from parent CLI
      class_option :trace, type: :boolean, default: false,
                           desc: "Show full backtrace on error"

      desc "references", "Validate that all references exist"
      option :debug_registry, type: :boolean,
                              desc: "Show registry contents for debugging"
      option :database, type: :string, required: true, aliases: "-d",
                        desc: "Path to UnitsDB database (required)"
      option :print_valid, type: :boolean, default: false,
                           desc: "Print valid references too"
      def references
        run_command(Commands::Validate::References, options)
      end

      desc "identifiers", "Check for uniqueness of identifier fields"
      option :database, type: :string, required: true, aliases: "-d",
                        desc: "Path to UnitsDB database (required)"

      def identifiers
        run_command(Commands::Validate::Identifiers, options)
      end

      desc "si_references",
           "Validate that each SI digital framework reference is unique per entity type"
      option :database, type: :string, required: true, aliases: "-d",
                        desc: "Path to UnitsDB database (required)"

      def si_references
        run_command(Commands::Validate::SiReferences, options)
      end

      desc "qudt_references",
           "Validate that each QUDT reference is unique per entity type"
      option :database, type: :string, required: true, aliases: "-d",
                        desc: "Path to UnitsDB database (required)"

      def qudt_references
        run_command(Commands::Validate::QudtReferences, options)
      end

      desc "ucum_references",
           "Validate that each UCUM reference is unique per entity type"
      option :database, type: :string, required: true, aliases: "-d",
                        desc: "Path to UnitsDB database (required)"

      def ucum_references
        run_command(Commands::Validate::UcumReferences, options)
      end

      private

      def run_command(command_class, options)
        command = command_class.new(options)
        command.run
      rescue Unitsdb::Errors::CLIRuntimeError => e
        handle_cli_error(e)
      rescue StandardError => e
        handle_error(e)
      end

      def handle_cli_error(error)
        if options[:trace]
          raise error
        else
          warn "Error: #{error.message}"
          exit 1
        end
      end

      def handle_error(error)
        if options[:trace]
          raise error
        else
          warn "Error: #{error.message}"
          exit 1
        end
      end
    end
  end
end
