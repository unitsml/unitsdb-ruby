# frozen_string_literal: true

module Unitsdb
  # Represents a localized string with a language tag
  class LocalizedString < Lutaml::Model::Serializable
    attribute :value, :string
    attribute :lang, :string

    def to_s
      "#{value} (#{lang})"
    end

    def downcase
      value&.downcase
    end
  end
end
