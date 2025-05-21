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
    # model Config.model_for(:prefixes)

    attribute :schema_version, :string
    attribute :version, :string
    attribute :prefixes, Prefix, collection: true
  end
end
