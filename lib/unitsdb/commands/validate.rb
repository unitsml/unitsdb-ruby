# frozen_string_literal: true

require "thor"
require_relative "validate/references"
require_relative "validate/identifiers"

module Unitsdb
  module Commands
    class ValidateCommand < Thor
      desc "references", "Validate that all references exist"
      subcommand "references", Validate::References

      desc "identifiers", "Check for uniqueness of identifier fields"
      subcommand "identifiers", Validate::Identifiers
    end
  end
end
