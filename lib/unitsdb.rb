# frozen_string_literal: true

require "lutaml/model"

module Unitsdb
  autoload :CLI, "unitsdb/cli"
  autoload :Config, "unitsdb/config"
  autoload :Commands, "unitsdb/commands"
  autoload :Database, "unitsdb/database"
  autoload :Dimension, "unitsdb/dimension"
  autoload :DimensionDetails, "unitsdb/dimension_details"
  autoload :DimensionReference, "unitsdb/dimension_reference"
  autoload :Dimensions, "unitsdb/dimensions"
  autoload :Errors, "unitsdb/errors"
  autoload :ExternalReference, "unitsdb/external_reference"
  autoload :Identifier, "unitsdb/identifier"
  autoload :LocalizedString, "unitsdb/localized_string"
  autoload :Prefix, "unitsdb/prefix"
  autoload :PrefixReference, "unitsdb/prefix_reference"
  autoload :Prefixes, "unitsdb/prefixes"
  autoload :Quantities, "unitsdb/quantities"
  autoload :Quantity, "unitsdb/quantity"
  autoload :QuantityReference, "unitsdb/quantity_reference"
  autoload :QudtUnit, "unitsdb/qudt"
  autoload :QudtQuantityKind, "unitsdb/qudt"
  autoload :QudtDimensionVector, "unitsdb/qudt"
  autoload :QudtSystemOfUnits, "unitsdb/qudt"
  autoload :QudtPrefix, "unitsdb/qudt"
  autoload :QudtVocabularies, "unitsdb/qudt"
  autoload :RootUnitReference, "unitsdb/root_unit_reference"
  autoload :Scale, "unitsdb/scale"
  autoload :ScaleProperties, "unitsdb/scale_properties"
  autoload :ScaleReference, "unitsdb/scale_reference"
  autoload :Scales, "unitsdb/scales"
  autoload :SiDerivedBase, "unitsdb/si_derived_base"
  autoload :SymbolPresentations, "unitsdb/symbol_presentations"
  autoload :UcumBaseUnit, "unitsdb/ucum"
  autoload :UcumPrefixValue, "unitsdb/ucum"
  autoload :UcumPrefix, "unitsdb/ucum"
  autoload :UcumUnitValueFunction, "unitsdb/ucum"
  autoload :UcumUnitValue, "unitsdb/ucum"
  autoload :UcumUnit, "unitsdb/ucum"
  autoload :UcumFile, "unitsdb/ucum"
  autoload :Unit, "unitsdb/unit"
  autoload :UnitReference, "unitsdb/unit_reference"
  autoload :UnitSystem, "unitsdb/unit_system"
  autoload :UnitSystemReference, "unitsdb/unit_system_reference"
  autoload :UnitSystems, "unitsdb/unit_systems"
  autoload :Units, "unitsdb/units"
  autoload :Utils, "unitsdb/utils"

  class << self
    # Returns the path to the bundled data directory containing YAML files
    def data_dir
      @data_dir ||= File.join(gem_dir, "lib", "unitsdb", "data")
    end

    # Returns a pre-loaded Database instance from the bundled data
    def database
      @database ||= Database.from_db(data_dir)
    end

    private

    def gem_dir
      @gem_dir ||= File.dirname(__dir__)
    end
  end
end
