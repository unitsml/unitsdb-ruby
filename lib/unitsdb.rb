# frozen_string_literal: true

require "lutaml/model"

require_relative "unitsdb/version"
require_relative "unitsdb/config"
require_relative "unitsdb/database"
require_relative "unitsdb/dimensions"
require_relative "unitsdb/prefixes"
require_relative "unitsdb/quantities"
require_relative "unitsdb/unit_systems"
require_relative "unitsdb/units"
module Unitsdb
  class Error < StandardError; end
end
