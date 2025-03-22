# frozen_string_literal: true

require_relative "quantity"

module Unitsdb
  class Quantities < Lutaml::Model::Serializable
    # model Config.model_for(:quantities)
    attribute :quantities, Quantity, collection: true
  end
end
