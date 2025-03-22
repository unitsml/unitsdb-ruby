# frozen_string_literal: true

require_relative "base"

module Unitsdb
  module Commands
    module Validate
      class Uniqueness < Base
        desc "check [INPUT]", "Check for uniqueness of 'short' and 'id' fields in a YAML file"
        option :all, type: :boolean, default: false, desc: "Check all YAML files in the repository"
        option :dir, type: :string, default: ".", desc: "Directory containing the YAML files"

        def check(input = nil)
          # Delegate to the main uniqueness command implementation
          Unitsdb::Commands::Uniqueness.new.check(input, options)
        end
      end
    end
  end
end
