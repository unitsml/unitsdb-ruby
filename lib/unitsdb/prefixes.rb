# frozen_string_literal: true

require_relative "prefix"
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
  class Prefixes < Lutaml::Model::Serializable
    attribute :prefix, Prefix, collection: true

    key_value do
      map to: :prefix, root_mappings: {
        id: :key
      }
    end
  end
end
