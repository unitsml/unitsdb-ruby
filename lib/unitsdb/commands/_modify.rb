# frozen_string_literal: true

require "thor"

module Unitsdb
  module Commands
    class ModifyCommand < Thor
      # Inherit trace option from parent CLI
      class_option :trace, type: :boolean, default: false,
                          desc: "Show full backtrace on error"

      desc "normalize INPUT OUTPUT",
           "Normalize a YAML file or all YAML files with --all"
      method_option :sort, type: :string,
                           default: "nist",
                           enum: ["short", "nist", "unitsml", "none"],
                           aliases: "-s",
                           desc: "Sort units by: 'short' (name), 'nist' (ID, default), 'unitsml' (ID), or 'none'"
      method_option :database, type: :string, required: true, aliases: "-d",
                               desc: "Path to UnitsDB database (required)"
      method_option :all, type: :boolean, default: false, aliases: "-a",
                          desc: "Process all YAML files in the repository"

      def normalize(input = nil, output = nil)
        run_command(Normalize, options, input, output)
      rescue Unitsdb::Errors::CLIRuntimeError => e
        handle_cli_error(e)
      rescue StandardError => e
        handle_error(e)
      end

      private

      def run_command(command_class, options, *args)
        command = command_class.new(options)
        command.run(*args)
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
