# frozen_string_literal: true

# references:
# - uri: http://si-digital-framework.org/quantities/LENG
#   type: normative
#   authority: si-digital-framework

module Unitsdb
  class ExternalReference < Identifier
    attribute :uri, :string
    attribute :type, :string, values: %w[normative informative]
    attribute :authority, :string
  end
end
