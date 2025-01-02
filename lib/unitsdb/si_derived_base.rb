# frozen_string_literal: true

# - id: NISTu1
#   prefix:
#   power: 1
# - id: NISTu1
#   prefix:
#   power: -1

class SiDerivedBase < Lutaml::Model::Serializable
  attribute :id, :string
  attribute :prefix, :string
  attribute :power, :integer

  key_value do
    map :id, to: :id
    map :prefix, to: :prefix
    map :power, to: :power
  end
end
