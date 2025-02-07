# frozen_string_literal: true

require_relative "../symbol_presentations"

module Unitsdb
  class Units
    class Symbol < SymbolPresentations
      model Config.model_for(:unit_symbol)

      attribute :id, :string
      attribute :mathml, :string

      key_value do
        map :id, to: :id
        map :mathml, to: :mathml
      end
    end
  end
end
