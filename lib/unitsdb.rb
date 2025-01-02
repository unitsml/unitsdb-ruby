# frozen_string_literal: true

require "lutaml/model"

# Lutaml::Model::Config.configure do |config|
#   require "lutaml/model/xml_adapter/nokogiri_adapter"
#   config.xml_adapter = Lutaml::Model::XmlAdapter::NokogiriAdapter
# end

module Unitsdb
  class Error < StandardError; end
end

require_relative "unitsdb/version"
require_relative "unitsdb/unit"
