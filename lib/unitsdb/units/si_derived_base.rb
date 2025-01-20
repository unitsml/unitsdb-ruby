# frozen_string_literal: true

# - id: NISTu1
#   prefix:
#   power: 1
# - id: NISTu1
#   prefix:
#   power: -1

module Unitsdb
  class Units
    class SiDerivedBase < Lutaml::Model::Serializable
      model Config.model_for(:si_deribed_base)

      attribute :id, :string
      attribute :prefix, :string
      attribute :power, :integer

      key_value do
        map :id, to: :id
        map :prefix, to: :prefix, render_nil: true
        map :power, to: :power
      end
    end
  end
end
