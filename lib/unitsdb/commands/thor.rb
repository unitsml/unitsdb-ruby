# frozen_string_literal: true

require "thor"

module Unitsdb
  module Commands
    # Base class for every Thor-based CLI surface in the gem. Owns the
    # shared `--trace` option, the `exit_on_failure?` policy, the
    # `run_command` dispatch helper, and the single error handler
    # (`handle_error`). Subclasses inherit these and provide only their
    # own `desc`/`option`/subcommand declarations.
    class Thor < ::Thor
      class_option :trace, type: :boolean, default: false,
                           desc: "Show full backtrace on error"

      def self.exit_on_failure?
        true
      end

      private

      # Instantiate `command_class` with `options` plus any extra
      # positional args, then call its `run` (or other public method).
      # All exceptions route through `handle_error`.
      def run_command(command_class, options, *args, method: :run)
        command_class.new(options).public_send(method, *args)
      rescue StandardError => e
        handle_error(e)
      end

      # Re-raise when `--trace` is set so the user sees the full
      # backtrace. Otherwise warn-and-exit-1 for a clean CLI UX.
      def handle_error(error)
        raise error if options[:trace]

        warn "Error: #{error.message}"
        exit 1
      end
    end
  end
end
