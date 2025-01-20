# frozen_string_literal: true

require_relative "../symbol_presentations"

#   symbol:
#     ascii: R
#     html: R
#     latex: R
#     unicode: R

module Unitsdb
  class Prefixes
    class Symbol < SymbolPresentations
      model Config.model_for(:prefix_symbol)
    end
  end
end
