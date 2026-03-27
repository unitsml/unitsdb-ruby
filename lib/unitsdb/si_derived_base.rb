# frozen_string_literal: true

# si_derived_bases:
# - power: 2
#   unit_reference:
#     id: NISTu1
#     type: nist
# - power: -2
#   unit_reference:
#     id: NISTu1
#     type: nist

module Unitsdb
  class SiDerivedBase < RootUnitReference
    # model Config.model_for(:si_derived_base)
  end
end
