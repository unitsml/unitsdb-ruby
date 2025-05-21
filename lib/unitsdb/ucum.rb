# frozen_string_literal: true

require "lutaml/model"

module Unitsdb
  # <base-unit Code="s" CODE="S" dim="T">
  #   <name>second</name>
  #   <printSymbol>s</printSymbol>
  #   <property>time</property>
  #  </base-unit>
  class UcumBaseUnit < Lutaml::Model::Serializable
    attribute :code_sensitive, :string
    attribute :code, :string
    attribute :dimension, :string
    attribute :name, :string
    attribute :print_symbol, :string, raw: true
    attribute :property, :string

    xml do
      root "base-unit"
      map_attribute "Code", to: :code_sensitive
      map_attribute "CODE", to: :code
      map_attribute "dim", to: :dimension
      map_element "name", to: :name
      map_element "printSymbol", to: :print_symbol
      map_element "property", to: :property
    end

    def identifier
      "ucum:base-unit:code:#{code_sensitive}"
    end
  end

  #  <prefix Code="Y" CODE="YA">
  #   <name>yotta</name>
  #   <printSymbol>Y</printSymbol>
  #   <value value="1e24">1 &#215; 10<sup>24</sup>
  #   </value>
  #  </prefix>

  class UcumPrefixValue < Lutaml::Model::Serializable
    attribute :value, :string
    attribute :content, :string

    xml do
      root "value"
      map_attribute "value", to: :value
      map_content to: :content
    end
  end

  class UcumPrefix < Lutaml::Model::Serializable
    attribute :code_sensitive, :string
    attribute :code, :string
    attribute :name, :string
    attribute :print_symbol, :string, raw: true
    attribute :value, UcumPrefixValue

    xml do
      root "prefix"
      map_attribute "Code", to: :code_sensitive
      map_attribute "CODE", to: :code
      map_element "name", to: :name
      map_element "printSymbol", to: :print_symbol
      map_element "value", to: :value
    end

    def identifier
      "ucum:prefix:code:#{code_sensitive}"
    end
  end

  #  <unit Code="10*" CODE="10*" isMetric="no" class="dimless">
  #   <name>the number ten for arbitrary powers</name>
  #   <printSymbol>10</printSymbol>
  #   <property>number</property>
  #   <value Unit="1" UNIT="1" value="10">10</value>
  #  </unit>

  #  <unit Code="gon" CODE="GON" isMetric="no" class="iso1000">
  #     <name>gon</name>
  #     <name>grade</name>
  #     <printSymbol>
  #        <sup>g</sup>
  #     </printSymbol>
  #     <property>plane angle</property>
  #     <value Unit="deg" UNIT="DEG" value="0.9">0.9</value>
  #  </unit>

  # <unit Code="[D'ag'U]" CODE="[D'AG'U]" isMetric="no" isArbitrary="yes"
  #       class="chemical">
  #   <name>D-antigen unit</name>
  #   <printSymbol/>
  #   <property>procedure defined amount of a poliomyelitis d-antigen substance</property>
  #   <value Unit="1" UNIT="1" value="1">1</value>
  #  </unit>

  #    <unit Code="Cel" CODE="CEL" isMetric="yes" isSpecial="yes" class="si">
  #     <name>degree Celsius</name>
  #     <printSymbol>&#176;C</printSymbol>
  #     <property>temperature</property>
  #     <value Unit="cel(1 K)" UNIT="CEL(1 K)">
  #        <function name="Cel" value="1" Unit="K"/>
  #     </value>
  #  </unit>

  class UcumUnitValueFunction < Lutaml::Model::Serializable
    attribute :name, :string
    attribute :value, :string
    attribute :unit_sensitive, :string

    xml do
      root "function"
      map_attribute "name", to: :name
      map_attribute "value", to: :value
      map_attribute "Unit", to: :unit_sensitive
    end
  end

  class UcumUnitValue < Lutaml::Model::Serializable
    attribute :unit_sensitive, :string
    attribute :unit, :string
    attribute :value, :string
    attribute :function, UcumUnitValueFunction
    attribute :content, :string

    xml do
      root "value"
      map_attribute "Unit", to: :unit_sensitive
      map_attribute "UNIT", to: :unit
      map_attribute "value", to: :value
      map_element "function", to: :function
      map_content to: :content
    end
  end

  class UcumUnit < Lutaml::Model::Serializable
    attribute :code_sensitive, :string
    attribute :code, :string
    attribute :is_metric, :string
    attribute :is_arbitrary, :string
    attribute :is_special, :string
    attribute :klass, :string
    attribute :name, :string, collection: true
    attribute :print_symbol, :string, raw: true
    attribute :property, :string
    attribute :value, UcumUnitValue

    xml do
      root "unit"
      map_attribute "Code", to: :code_sensitive
      map_attribute "CODE", to: :code
      map_attribute "isMetric", to: :is_metric
      map_attribute "isArbitrary", to: :is_arbitrary
      map_attribute "isSpecial", to: :is_special
      map_attribute "class", to: :klass

      map_element "name", to: :name
      map_element "printSymbol", to: :print_symbol
      map_element "property", to: :property
      map_element "value", to: :value
    end

    def identifier
      # Use empty string if klass is not present
      k = klass || ""
      "ucum:unit:#{k}:code:#{code_sensitive}"
    end
  end

  # This is the root element of the UCUM XML "ucum-essence.xml" file.
  #
  # <root xmlns="http://unitsofmeasure.org/ucum-essence" version="2.2" revision="N/A"
  #     revision-date="2024-06-17">

  class UcumFile < Lutaml::Model::Serializable
    attribute :revision, :string
    attribute :version, :string
    attribute :revision_date, :date
    attribute :prefixes, UcumPrefix, collection: true
    attribute :base_units, UcumBaseUnit, collection: true
    attribute :units, UcumUnit, collection: true

    xml do
      root "root"
      namespace "http://unitsofmeasure.org/ucum-essence"
      map_attribute "version", to: :version
      map_attribute "revision", to: :revision
      map_attribute "revision-date", to: :revision_date

      map_element "prefix", to: :prefixes
      map_element "base-unit", to: :base_units
      map_element "unit", to: :units
    end

    # No adapter registration needed
  end
end
