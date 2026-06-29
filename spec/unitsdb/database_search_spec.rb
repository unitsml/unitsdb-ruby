# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unitsdb::Database do
  let(:fixtures_dir) { "data" }
  let(:database) { described_class.from_db(fixtures_dir) }

  around do |example|
    Unitsdb.reset_database_cache!
    Lutaml::Model::GlobalContext.reset!
    example.run
  ensure
    Unitsdb.reset_database_cache!
    Lutaml::Model::GlobalContext.reset!
  end

  describe "search and lookup functionality" do
    it "finds entities using search by text with type filters" do
      results = database.search(text: "meter")
      expect(results).not_to be_empty
      expect(results.any?(Unitsdb::Unit)).to be(true)

      results = database.search(text: "kilo", type: "prefixes")
      expect(results.all?(Unitsdb::Prefix)).to be(true)

      expect(database.search(text: "nonexistentterm123456")).to be_empty
      expect(database.search(text: nil)).to be_empty
    end

    it "finds entities by id and type" do
      expect(database.find_by_type(id: "NISTu1", type: "units")).to be_a(Unitsdb::Unit)
      expect(database.find_by_type(id: "NonExistentID", type: "units")).to be_nil

      expect(database.get_by_id(id: "NISTu1")).to be_a(Unitsdb::Unit)
      expect(database.get_by_id(id: "NISTu1", type: "nist")).to be_a(Unitsdb::Unit)
      expect(database.get_by_id(id: "NonExistentID")).to be_nil
      expect(database.get_by_id(id: "NISTu1", type: "wrong_type")).to be_nil
    end

    it "rejects an unknown collection name" do
      expect { database.find_by_type(id: "x", type: "bogus") }.to raise_error(ArgumentError)
      expect { database.search(text: "x", type: "bogus") }.to raise_error(ArgumentError)
    end
  end

  describe "#find_by_symbol" do
    it "matches Units by ASCII symbol case-insensitively" do
      results = database.find_by_symbol("m")
      expect(results).not_to be_empty
      expect(results.any?(Unitsdb::Unit)).to be(true)
    end

    it "matches Prefixes when no entity_type is given" do
      results = database.find_by_symbol("k")
      expect(results.any?(Unitsdb::Prefix)).to be(true)
    end

    it "narrows to one collection when entity_type is provided" do
      only_units = database.find_by_symbol("m", "units")
      expect(only_units).not_to be_empty
      expect(only_units.all?(Unitsdb::Unit)).to be(true)

      only_prefixes = database.find_by_symbol("k", "prefixes")
      expect(only_prefixes.all?(Unitsdb::Prefix)).to be(true)
    end

    it "returns an empty array for an unknown symbol" do
      expect(database.find_by_symbol("zz-not-a-symbol")).to eq([])
    end

    it "returns an empty array when called with nil" do
      expect(database.find_by_symbol(nil)).to eq([])
    end

    it "raises ArgumentError when the entity_type is not a symbol-carrying collection" do
      expect { database.find_by_symbol("m", "quantities") }.to raise_error(ArgumentError)
    end
  end

  describe "#match_entities" do
    it "returns an empty hash when value is nil" do
      expect(database.match_entities(value: nil)).to eq({})
    end

    it "matches Units by short" do
      result = database.match_entities(value: "meter")
      expect(result[:exact]).not_to be_nil
      expect(result[:exact].any? { |m| m[:entity].is_a?(Unitsdb::Unit) }).to be(true)
    end

    it "matches by symbol when match_type is 'symbol'" do
      result = database.match_entities(value: "m", match_type: "symbol")
      expect(result[:symbol_match]).not_to be_nil
      expect(result[:symbol_match].first[:match_desc]).to eq("symbol_match")
    end

    it "limits scope when entity_type is provided" do
      result = database.match_entities(value: "meter", entity_type: "units")
      expect(result[:exact].all? { |m| m[:entity].is_a?(Unitsdb::Unit) }).to be(true)
    end

    it "returns an empty hash for an unknown value" do
      expect(database.match_entities(value: "zz-not-an-entity")).to eq({})
    end

    it "drops empty categories from the result" do
      result = database.match_entities(value: "meter")
      expect(result.key?(:symbol_match)).to be(false) unless result[:symbol_match]&.any?
    end
  end

  describe "#validate_uniqueness" do
    it "returns a hash with :short and :id keys" do
      result = database.validate_uniqueness
      expect(result).to include(:short, :id)
    end

    it "flags a synthetic duplicate identifier" do
      dup_id = Unitsdb::Identifier.new(id: "NISTu1", type: "nist")
      unit = Unitsdb::Unit.new(identifiers: [dup_id])
      database.units << unit

      result = database.validate_uniqueness
      expect(result[:id]["units"]).to include("NISTu1")
    end

    it "flags a synthetic duplicate short name" do
      dup_short = database.units.first.short
      unit = Unitsdb::Unit.new(
        identifiers: [Unitsdb::Identifier.new(id: "NISTu-synthetic", type: "nist")],
        short: dup_short,
      )
      database.units << unit

      result = database.validate_uniqueness
      expect(result[:short]["units"]).to include(dup_short)
    end
  end

  describe "#validate_references" do
    it "returns a hash (empty when bundled DB has no broken refs)" do
      result = database.validate_references
      expect(result).to be_a(Hash)
    end

    it "flags a Unit whose unit_system_reference points nowhere" do
      bogus_ref = Unitsdb::UnitSystemReference.new(id: "bogus-system", type: "unitsml")
      unit = Unitsdb::Unit.new(
        identifiers: [Unitsdb::Identifier.new(id: "NISTu-test", type: "nist")],
        short: "test_unit",
        names: [Unitsdb::LocalizedString.new(value: "test", lang: "en")],
        unit_system_reference: [bogus_ref],
      )
      database.units << unit

      result = database.validate_references
      expect(result["units"]).to include(
        "units:index:#{database.units.size - 1}:unit_system_reference[0]",
      )
    end

    it "flags a Unit whose root_units.unit_reference points nowhere" do
      bogus_root = Unitsdb::RootUnitReference.new(
        unit_reference: Unitsdb::UnitReference.new(id: "NISTu-missing", type: "nist"),
      )
      unit = Unitsdb::Unit.new(
        identifiers: [Unitsdb::Identifier.new(id: "NISTu-test-2", type: "nist")],
        short: "test_unit_2",
        names: [Unitsdb::LocalizedString.new(value: "test 2", lang: "en")],
        root_units: [bogus_root],
      )
      database.units << unit

      result = database.validate_references
      path = "units:index:#{database.units.size - 1}:root_units.0.unit_reference"
      expect(result["units"]).to include(path)
    end
  end
end
