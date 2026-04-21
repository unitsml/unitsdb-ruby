# frozen_string_literal: true

require "lutaml/model"
require "unitsdb/config"
require "unitsdb/identifier"
require "unitsdb/localized_string"
require "unitsdb/symbol_presentations"
require "unitsdb/scale_properties"
require "unitsdb/unit_reference"
require "unitsdb/prefix_reference"
require "unitsdb/quantity_reference"
require "unitsdb/dimension_reference"
require "unitsdb/unit_system_reference"
require "unitsdb/scale_reference"
require "unitsdb/external_reference"
require "unitsdb/root_unit_reference"
require "unitsdb/si_derived_base"
require "unitsdb/dimension_details"
require "unitsdb/dimension"
require "unitsdb/prefix"
require "unitsdb/unit_system"
require "unitsdb/quantity"
require "unitsdb/scale"
require "unitsdb/unit"
require "unitsdb/dimensions"
require "unitsdb/prefixes"
require "unitsdb/quantities"
require "unitsdb/scales"
require "unitsdb/unit_systems"
require "unitsdb/units"
require "unitsdb/database"
require "unitsdb/qudt"
require "unitsdb/ucum"

module Unitsdb
  unless RUBY_ENGINE == "opal"
    autoload :Cli, "unitsdb/cli"
    autoload :Commands, "unitsdb/commands"
  end
  autoload :Errors, "unitsdb/errors"
  autoload :Utils, "unitsdb/utils"

  class << self
    # Returns the path to the bundled data directory containing YAML files
    def data_dir
      @data_dir ||= File.join(gem_dir, "data")
    end

    # Returns a pre-loaded Database instance from the bundled data
    def database(context: Config.context_id)
      context_id = context.to_sym
      Config.context if context_id == Config.context_id
      klass = Config.resolve_type(:database, context: context_id)
      databases[context_id] ||= klass.from_db(data_dir, context: context_id)
    end

    private

    def databases
      @databases ||= {}
    end

    def gem_dir
      @gem_dir ||= File.dirname(__dir__)
    end
  end
end
