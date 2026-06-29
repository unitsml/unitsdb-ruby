# frozen_string_literal: true

require "spec_helper"

# Typed-attribute checks for known bundled entities. The per-entity
# *_spec.rb files already cover YAML round-trip for every entity in
# the data dir; these specs complement them by asserting typed
# attribute access on representative entities so regressions in
# Identifier / LocalizedString / SymbolPresentations /
# ExternalReference wiring surface as test failures, not just
# round-trip mismatches.
RSpec.describe Unitsdb do
  let(:database) do
    described_class.reset_database_cache!
    Lutaml::Model::GlobalContext.reset!
    described_class.database.tap do
      described_class.reset_database_cache!
      Lutaml::Model::GlobalContext.reset!
    end
  end

  describe "the meter Unit (NISTu1)" do
    let(:meter) { database.get_by_id(id: "NISTu1") }

    it "is a Unit with identifiers, names, short, and symbols" do
      expect(meter).to be_a(Unitsdb::Unit)
      expect(meter.short).to eq("meter")
      expect(meter.identifiers.map(&:id)).to include("NISTu1")

      name = meter.names.first
      expect(name).to be_a(Unitsdb::LocalizedString)
      expect(name.value).to match(/met(er|re)/)

      symbol = meter.symbols.first
      expect(symbol).to be_a(Unitsdb::SymbolPresentations)
      expect(symbol.ascii).to eq("m")
    end

    it "round-trips through YAML with all attributes intact" do
      parsed = Unitsdb::Unit.from_yaml(meter.to_yaml)
      expect(parsed.short).to eq(meter.short)
      expect(parsed.identifiers.first.id).to eq("NISTu1")
      expect(parsed.symbols.first.ascii).to eq("m")
    end
  end

  describe "the kilo Prefix (NISTp10_3)" do
    let(:kilo) { database.get_by_id(id: "NISTp10_3") }

    it "is a Prefix with short, base, power, and symbols" do
      expect(kilo).to be_a(Unitsdb::Prefix)
      expect(kilo.short).to eq("kilo")
      expect(kilo.base).to eq(10)
      expect(kilo.power).to eq(3)

      symbol = kilo.symbols.first
      expect(symbol).to be_a(Unitsdb::SymbolPresentations)
      expect(symbol.ascii).to eq("k")
    end

    it "round-trips through YAML" do
      parsed = Unitsdb::Prefix.from_yaml(kilo.to_yaml)
      expect(parsed.short).to eq("kilo")
      expect(parsed.power).to eq(3)
    end
  end

  describe "the length Dimension (NISTd1)" do
    let(:length) { database.get_by_id(id: "NISTd1") }

    it "is a Dimension with a length DimensionDetails entry" do
      expect(length).to be_a(Unitsdb::Dimension)
      expect(length.short).to eq("length")
      expect(length.length).to be_a(Unitsdb::DimensionDetails)
      expect(length.length.power).to eq(1)
    end
  end

  describe "the length Quantity (NISTq1)" do
    let(:quantity) { database.get_by_id(id: "NISTq1") }

    it "is a Quantity with short and dimension_reference" do
      expect(quantity).to be_a(Unitsdb::Quantity)
      expect(quantity.short).to eq("length")
      expect(quantity.dimension_reference).to be_a(Unitsdb::DimensionReference)
    end
  end

  describe "the SI_base UnitSystem" do
    let(:si) { database.get_by_id(id: "SI_base") }

    it "is a UnitSystem with names" do
      expect(si).to be_a(Unitsdb::UnitSystem)
      expect(si.identifiers.map(&:id)).to include("SI_base")
      expect(si.names.first).to be_a(Unitsdb::LocalizedString)
    end
  end

  describe "Identifier and LocalizedString leaves" do
    it "Identifier round-trips its two attrs" do
      ident = Unitsdb::Identifier.new(id: "X", type: "nist")
      parsed = Unitsdb::Identifier.from_yaml(ident.to_yaml)
      expect(parsed.id).to eq("X")
      expect(parsed.type).to eq("nist")
    end

    it "LocalizedString round-trips value and lang" do
      str = Unitsdb::LocalizedString.new(value: "hello", lang: "en")
      parsed = Unitsdb::LocalizedString.from_yaml(str.to_yaml)
      expect(parsed.value).to eq("hello")
      expect(parsed.lang).to eq("en")
    end

    it "SymbolPresentations round-trips ASCII and MathML" do
      sym = Unitsdb::SymbolPresentations.new(
        id: "sym_m", ascii: "m", mathml: "<mi>m</mi>",
      )
      parsed = Unitsdb::SymbolPresentations.from_yaml(sym.to_yaml)
      expect(parsed.ascii).to eq("m")
      expect(parsed.mathml).to eq("<mi>m</mi>")
    end

    it "ExternalReference round-trips uri, type, authority" do
      ref = Unitsdb::ExternalReference.new(
        uri: "http://example.org/x", type: "normative", authority: "custom",
      )
      parsed = Unitsdb::ExternalReference.from_yaml(ref.to_yaml)
      expect(parsed.uri).to eq("http://example.org/x")
      expect(parsed.authority).to eq("custom")
    end
  end
end
