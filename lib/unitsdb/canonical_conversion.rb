module Unitsdb
  class CanonicalConversion < Lutaml::Model::Serializable
    attribute :factor, :string
    attribute :offset, :string
    attribute :root_units, RootUnitReference, collection: true
  end

  Config.register_model(CanonicalConversion, id: :canonical_conversion)
end
