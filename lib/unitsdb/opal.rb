# frozen_string_literal: true

# Opal entry point for unitsdb.
#
# Under MRI, lib/unitsdb.rb uses autoload for lazy loading. Under Opal,
# autoload does not lazy-execute, so a single eager-require file lists
# every entry point the consumer (unitsml-ruby, plurimath-js) needs.
# Consumers add `-r unitsdb/opal` to their Opal compile command.

require "lutaml/model"
require "unitsdb"
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
require "unitsdb/errors"
require "unitsdb/utils"
