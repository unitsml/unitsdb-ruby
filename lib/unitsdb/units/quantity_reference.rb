# frozen_string_literal: true

module Unitsdb
  class Units
    class QuantityReference < Lutaml::Model::Serializable
      model Config.model_for(:quantity_reference)

      attribute :name, :string
      attribute :url, :string

      key_value do
        map :name, to: :name
        map :url, to: :url
      end
    end
  end
end
