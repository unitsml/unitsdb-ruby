# frozen_string_literal: true

require "lutaml/model"

module Unitsdb
  # All model constants are autoloaded from their respective files.
  # Config.build_registry triggers `eager_load_models!` so the type
  # registry is complete before iteration — otherwise autoload would
  # leave unreferenced models (Scale, Qudt*, Ucum*) unregistered.

  autoload :Config, "unitsdb/config"
  autoload :Errors, "unitsdb/errors"
  autoload :Utils, "unitsdb/utils"
  autoload :Database, "unitsdb/database"

  # Leaf models
  autoload :Identifier, "unitsdb/identifier"
  autoload :LocalizedString, "unitsdb/localized_string"
  autoload :SymbolPresentations, "unitsdb/symbol_presentations"
  autoload :ScaleProperties, "unitsdb/scale_properties"

  # Reference models
  autoload :UnitReference, "unitsdb/unit_reference"
  autoload :PrefixReference, "unitsdb/prefix_reference"
  autoload :QuantityReference, "unitsdb/quantity_reference"
  autoload :DimensionReference, "unitsdb/dimension_reference"
  autoload :UnitSystemReference, "unitsdb/unit_system_reference"
  autoload :ScaleReference, "unitsdb/scale_reference"
  autoload :ExternalReference, "unitsdb/external_reference"
  autoload :RootUnitReference, "unitsdb/root_unit_reference"
  autoload :SiDerivedBase, "unitsdb/si_derived_base"
  autoload :DimensionDetails, "unitsdb/dimension_details"

  # Entity models
  autoload :Dimension, "unitsdb/dimension"
  autoload :Prefix, "unitsdb/prefix"
  autoload :UnitSystem, "unitsdb/unit_system"
  autoload :Quantity, "unitsdb/quantity"
  autoload :Scale, "unitsdb/scale"
  autoload :Unit, "unitsdb/unit"

  # Collection container models
  autoload :Dimensions, "unitsdb/dimensions"
  autoload :Prefixes, "unitsdb/prefixes"
  autoload :Quantities, "unitsdb/quantities"
  autoload :Scales, "unitsdb/scales"
  autoload :UnitSystems, "unitsdb/unit_systems"
  autoload :Units, "unitsdb/units"

  # QUDT vocabulary models — all defined in unitsdb/qudt.rb
  autoload :QudtUnit, "unitsdb/qudt"
  autoload :QudtQuantityKind, "unitsdb/qudt"
  autoload :QudtDimensionVector, "unitsdb/qudt"
  autoload :QudtSystemOfUnits, "unitsdb/qudt"
  autoload :QudtPrefix, "unitsdb/qudt"
  autoload :QudtVocabularies, "unitsdb/qudt"

  # UCUM XML models — all defined in unitsdb/ucum.rb
  autoload :UcumBaseUnit, "unitsdb/ucum"
  autoload :UcumPrefixValue, "unitsdb/ucum"
  autoload :UcumPrefix, "unitsdb/ucum"
  autoload :UcumUnitValueFunction, "unitsdb/ucum"
  autoload :UcumUnitValue, "unitsdb/ucum"
  autoload :UcumUnit, "unitsdb/ucum"
  autoload :UcumNamespace, "unitsdb/ucum"
  autoload :UcumFile, "unitsdb/ucum"

  # CLI and Commands pull in Thor, which doesn't run under Opal.
  unless RUBY_ENGINE == "opal"
    autoload :Cli, "unitsdb/cli"
    autoload :Commands, "unitsdb/commands"
  end

  # Constants eagerly loaded so Lutaml::Model type registrations are
  # complete before Config.build_registry iterates them. Listed
  # explicitly so unreferenced models (Scale, Qudt*, Ucum*) still
  # register themselves via their file-bottom `Config.register_model`
  # calls.
  MODELS = %i[
    Identifier
    LocalizedString
    SymbolPresentations
    ScaleProperties
    UnitReference
    PrefixReference
    QuantityReference
    DimensionReference
    UnitSystemReference
    ScaleReference
    ExternalReference
    RootUnitReference
    SiDerivedBase
    DimensionDetails
    Dimension
    Prefix
    UnitSystem
    Quantity
    Scale
    Unit
    Dimensions
    Prefixes
    Quantities
    Scales
    UnitSystems
    Units
    Database
    QudtUnit
    QudtQuantityKind
    QudtDimensionVector
    QudtSystemOfUnits
    QudtPrefix
    QudtVocabularies
    UcumBaseUnit
    UcumPrefixValue
    UcumPrefix
    UcumUnitValueFunction
    UcumUnitValue
    UcumUnit
    UcumNamespace
    UcumFile
  ].freeze

  class << self
    # Returns the path to the bundled data directory containing YAML files
    def data_dir
      @data_dir ||= File.join(gem_dir, "data")
    end

    # Returns a pre-loaded Database instance from the bundled data
    def database(context: Config.context_id)
      context_id = context.to_sym
      Config.ensure_default_context! if context_id == Config.context_id
      klass = Config.resolve_type(:database, context: context_id)
      databases[context_id] ||= klass.from_db(data_dir, context: context_id)
    end

    # Drop the memoized Database instances so the next `database` call
    # reloads from disk. Specs use this between examples.
    def reset_database_cache!
      @databases = nil
    end

    # Force every autoloaded model to load AND register itself with
    # Config. The per-file `Config.register_model(Class, id: :foo)`
    # calls at file-bottom run the first time a model loads, but
    # `Config.capture_state` / `restore_state` can wipe those entries
    # between tests. Re-registering here makes the registry
    # self-healing across snapshot/restore cycles.
    def eager_load_models!
      MODELS.each do |sym|
        klass = const_get(sym)
        next unless klass.is_a?(Class) && klass < ::Lutaml::Model::Serializable

        Config.register_model(klass, id: model_id_for(klass))
      end
    end

    private

    def model_id_for(klass)
      klass.name.split("::").last
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        .gsub(/([a-z\d])([A-Z])/, '\1_\2')
        .downcase
        .to_sym
    end

    def databases
      @databases ||= {}
    end

    def gem_dir
      @gem_dir ||= File.dirname(__dir__)
    end
  end
end
