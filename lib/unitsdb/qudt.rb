# frozen_string_literal: true

module Unitsdb
  # QUDT Unit from units vocabulary
  # Example: http://qudt.org/vocab/unit/M (meter)
  class QudtUnit < Lutaml::Model::Serializable
    attribute :uri, :string
    attribute :label, :string
    attribute :symbol, :string
    attribute :has_quantity_kind, :string
    attribute :has_dimension_vector, :string
    attribute :conversion_multiplier, :float
    attribute :conversion_offset, :float
    attribute :description, :string
    attribute :si_exact_match, :string

    def identifier
      "qudt:unit:#{uri}"
    end
  end
  Config.register_model(QudtUnit, id: :qudt_unit)

  # QUDT QuantityKind from quantitykinds vocabulary
  # Example: http://qudt.org/vocab/quantitykind/Length
  class QudtQuantityKind < Lutaml::Model::Serializable
    attribute :uri, :string
    attribute :label, :string
    attribute :has_dimension_vector, :string
    attribute :description, :string
    attribute :symbol, :string
    attribute :si_exact_match, :string

    def identifier
      "qudt:quantitykind:#{uri}"
    end
  end
  Config.register_model(QudtQuantityKind, id: :qudt_quantity_kind)

  # QUDT DimensionVector from dimensionvectors vocabulary
  # Example: http://qudt.org/vocab/dimensionvector/A0E0L1I0M0H0T0D0
  class QudtDimensionVector < Lutaml::Model::Serializable
    attribute :uri, :string
    attribute :label, :string
    attribute :dimension_exponent_for_length, :integer
    attribute :dimension_exponent_for_mass, :integer
    attribute :dimension_exponent_for_time, :integer
    attribute :dimension_exponent_for_electric_current, :integer
    attribute :dimension_exponent_for_thermodynamic_temperature, :integer
    attribute :dimension_exponent_for_amount_of_substance, :integer
    attribute :dimension_exponent_for_luminous_intensity, :integer
    attribute :description, :string

    def identifier
      "qudt:dimensionvector:#{uri}"
    end
  end
  Config.register_model(QudtDimensionVector, id: :qudt_dimension_vector)

  # QUDT SystemOfUnits from sou vocabulary
  # Example: http://qudt.org/vocab/sou/SI
  class QudtSystemOfUnits < Lutaml::Model::Serializable
    attribute :uri, :string
    attribute :label, :string
    attribute :abbreviation, :string
    attribute :description, :string

    def identifier
      "qudt:sou:#{uri}"
    end
  end
  Config.register_model(QudtSystemOfUnits, id: :qudt_system_of_units)

  # QUDT Prefix from prefixes vocabulary
  # Example: http://qudt.org/vocab/prefix/Kilo
  class QudtPrefix < Lutaml::Model::Serializable
    attribute :uri, :string
    attribute :label, :string
    attribute :symbol, :string
    attribute :prefix_multiplier, :float
    attribute :prefix_multiplier_sn, :string
    attribute :ucum_code, :string
    attribute :si_exact_match, :string
    attribute :description, :string
    attribute :prefix_type, :string # "DecimalPrefix" or "BinaryPrefix"

    def identifier
      "qudt:prefix:#{uri}"
    end
  end
  Config.register_model(QudtPrefix, id: :qudt_prefix)

  # Container for all QUDT vocabularies
  class QudtVocabularies
    attr_accessor :units, :quantity_kinds, :dimension_vectors,
                  :systems_of_units, :prefixes

    def initialize
      @units = []
      @quantity_kinds = []
      @dimension_vectors = []
      @systems_of_units = []
      @prefixes = []
    end
  end
end
