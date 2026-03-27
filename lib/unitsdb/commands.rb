# frozen_string_literal: true

module Unitsdb
  module Commands
    autoload :ModifyCommand, "unitsdb/commands/_modify"
    autoload :Base, "unitsdb/commands/base"
    autoload :CheckSi, "unitsdb/commands/check_si"
    autoload :CheckSiCommand, "unitsdb/commands/check_si"
    autoload :Get, "unitsdb/commands/get"
    autoload :Normalize, "unitsdb/commands/normalize"
    autoload :Qudt, "unitsdb/commands/qudt"
    autoload :QudtCommand, "unitsdb/commands/qudt"
    autoload :Release, "unitsdb/commands/release"
    autoload :Search, "unitsdb/commands/search"
    autoload :Ucum, "unitsdb/commands/ucum"
    autoload :UcumCommand, "unitsdb/commands/ucum"
    autoload :Validate, "unitsdb/commands/validate"
    autoload :ValidateCommand, "unitsdb/commands/validate"
  end
end
