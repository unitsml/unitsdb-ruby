# frozen_string_literal: true

module Unitsdb
  class Units
    class System < Lutaml::Model::Serializable
      model Config.model_for(:system)

      attribute :name, :string
      attribute :type, :string

      key_value do
        map :type, to: :type
        map :name, to: :name
      end
    end
  end
end
