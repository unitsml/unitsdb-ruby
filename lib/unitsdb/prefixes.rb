# frozen_string_literal: true

require_relative "prefixes/prefix"
# ---
# NISTp10_30:
#   name: quetta
#   symbol:
#     ascii: Q
#     html: Q
#     latex: Q
#     unicode: Q
#   base: 10
#   power: 30

module Unitsdb
  class Prefixes
    include Lutaml::Model::Serialize

    model Config.model_for(:prefixes)

    attribute :prefixes, Prefix, collection: true

    key_value do
      map to: :prefixes, root_mappings: {
        id: :key
      }
    end
  end
end
