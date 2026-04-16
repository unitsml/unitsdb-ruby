# frozen_string_literal: true

module Unitsdb
  class Identifier < Lutaml::Model::Serializable
    attribute :id, :string
    attribute :type, :string
  end

  Configuration.register_model(Identifier, id: :identifier)
end
