# frozen_string_literal: true

require "thor"
require_relative "validate/references"
require_relative "validate/uniqueness"
require_relative "validate/identifiers"

module Unitsdb
  module Commands
    class ValidateCommand < Thor
      desc "references", "Validate that all references exist"
      subcommand "references", Validate::References

      desc "uniqueness", "Check for uniqueness of 'short' and 'id' fields (legacy, use identifiers instead)"
      subcommand "uniqueness", Validate::Uniqueness

      desc "identifiers", "Check for uniqueness of identifier fields"
      subcommand "identifiers", Validate::Identifiers
    end
  end
end
