# frozen_string_literal: true

module Unitsdb
  class UnitReference < Lutaml::Model::Serializable
    attribute :name, :string
    attribute :url, :string

    key_value do
      map :name, to: :name
      map :url, to: :url
    end
  end
end
