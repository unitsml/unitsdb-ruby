# frozen_string_literal: true

require "thor"

module Unitsdb
  module Commands
    class ModifyCommand < Thor
      desc "normalize [INPUT] [OUTPUT]", "Normalize a YAML file or all YAML files with --all"
      method_option :sort, type: :string, default: "nist",
                           desc: "Sort units by: 'short' (name), 'nist' (ID, default), 'unitsml' (ID), or 'none'"
      method_option :database, type: :string, required: true, aliases: "-d",
                               desc: "Path to UnitsDB database (required)"
      method_option :all, type: :boolean, default: false, aliases: "-a",
                          desc: "Process all YAML files in the repository"

      def normalize(input = nil, output = nil)
        require_relative "normalize"
        Normalize.new(options).run(input, output)
      end
    end
  end
end
