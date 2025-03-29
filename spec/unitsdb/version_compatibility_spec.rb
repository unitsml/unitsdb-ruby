# frozen_string_literal: true

RSpec.describe "UnitsDB 2.0.0 Features" do
  let(:database_path) { File.join(__dir__, "../fixtures/unitsdb/") }
  let(:db) { Unitsdb::Database.from_db(database_path) }

  describe "version validation" do
    it "verifies database is version 2.0.0" do
      expect(db.schema_version).to eq("2.0.0")
    end
  end

  describe "multilingual support" do
    it "handles multilingual names in both units and quantities" do
      # Test units multilingual support
      meter = db.find_by_type(id: "NISTu1", type: "units")
      expect(meter.names).to be_an(Array)
      expect(meter.names.first).to respond_to(:value)
      expect(meter.names.first).to respond_to(:lang)

      english_names = meter.names.select { |n| n.lang == "en" }.map(&:value)
      french_names = meter.names.select { |n| n.lang == "fr" }.map(&:value)
      expect(english_names).to include("metre")
      expect(french_names).to include("mètre")

      # Test quantities multilingual support
      length = db.find_by_type(id: "NISTq1", type: "quantities")
      expect(length.names).to be_an(Array)
      expect(length.names.first).to respond_to(:value)
      english_names = length.names.select { |n| n.lang == "en" }.map(&:value)
      expect(english_names).to include("length")
    end
  end

  describe "multiple symbol formats" do
    it "handles multiple symbol formats for both units and prefixes" do
      # Test unit symbols
      meter = db.find_by_type(id: "NISTu1", type: "units")
      expect(meter.symbols).to be_an(Array)
      symbol = meter.symbols.first
      expect(symbol).to respond_to(:ascii)
      expect(symbol).to respond_to(:html)
      expect(symbol).to respond_to(:latex)

      # Test prefix symbols
      kilo = db.find_by_type(id: "NISTp10_3", type: "prefixes")
      expect(kilo.symbols).to be_an(Array)
      symbol = kilo.symbols.first
      expect(symbol).to respond_to(:ascii)
      expect(symbol.ascii).to eq("k")
    end
  end

  describe "find_by_symbol functionality" do
    it "finds entities by symbol" do
      # Find units by symbol
      units = db.find_by_symbol("m", "units")
      expect(units).to be_an(Array)
      expect(units.map(&:short)).to include("meter")

      # Find prefixes by symbol
      prefixes = db.find_by_symbol("k", "prefixes")
      expect(prefixes).to be_an(Array)
      expect(prefixes.map(&:short)).to include("kilo")
    end
  end
end
