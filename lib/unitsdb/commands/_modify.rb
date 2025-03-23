# frozen_string_literal: true

require "thor"

module Unitsdb
  module Commands
    class ModifyCommand < Thor
      desc "normalize [INPUT] [OUTPUT]", "Normalize a YAML file or all YAML files with --all"
      method_option :sort, type: :boolean, default: true, desc: "Sort keys alphabetically"
      method_option :database, type: :string, required: true, aliases: "-d",
                               desc: "Path to UnitsDB database (required)"
      method_option :all, type: :boolean, default: false, aliases: "-a",
                          desc: "Process all YAML files in the repository"

      def normalize(input = nil, output = nil)
        require_relative "normalize"
        Normalize.new.yaml(input, output, options)
      end
    end
  end
end
