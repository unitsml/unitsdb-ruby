require_relative "symbol"

module Unitsdb
  class UnitSymbol < Symbol
    attribute :id, :string
    attribute :mathml, :string

    key_value do
      map :id, to: :id
      map :mathml, to: :mathml
    end
  end
end
