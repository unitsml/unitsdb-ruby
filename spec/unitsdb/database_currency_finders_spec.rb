# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Unitsdb::Database do
  let(:data_dir) { File.expand_path("../../data", __dir__) }
  let(:fixture_dir) do
    dir = File.join(Dir.mktmpdir, "currencies-data")
    Dir.mkdir(dir)
    Unitsdb::Database::Loader::REQUIRED_DATABASE_FILES.each_value do |filename|
      FileUtils.cp(File.join(data_dir, filename), File.join(dir, filename))
    end
    File.write(File.join(dir, "currencies.yaml"), fixture_currencies)
    dir
  end
  let(:database) do
    Unitsdb.reset_database_cache!
    Lutaml::Model::GlobalContext.reset!
    described_class.from_db(fixture_dir)
  end
  let(:fixture_currencies) do
    <<~YAML
      schema_version: "2.2.0"
      currencies:
      - identifiers:
        - type: iso4217
          id: EUR
        - type: iso4217_numeric
          id: "978"
        - type: unitsml
          id: cur:EUR
        names:
        - value: "Euro"
          lang: en
        symbols:
        - unicode: "€"
          ascii: EUR
          id: EUR
        minor_unit_exponent: 2
        status: active
        unit_system_reference:
        - type: unitsml
          id: us:iso-4217
        quantity_references:
        - type: unitsml
          id: q:monetary_value
      - identifiers:
        - type: iso4217
          id: AUD
        - type: iso4217_numeric
          id: "036"
        - type: unitsml
          id: cur:AUD
        names:
        - value: "Australian Dollar"
          lang: en
        symbols:
        - unicode: "A$"
          ascii: AUD
          id: AUD
        minor_unit_exponent: 2
        status: active
        unit_system_reference:
        - type: unitsml
          id: us:iso-4217
        quantity_references:
        - type: unitsml
          id: q:monetary_value
    YAML
  end

  after do
    FileUtils.rm_rf(fixture_dir)
    Unitsdb.reset_database_cache!
    Lutaml::Model::GlobalContext.reset!
  end

  describe "#find_by_code" do
    it "finds by alpha code, case-insensitively" do
      expect(database.find_by_code("EUR").identifiers.map(&:id)).to include("cur:EUR")
      expect(database.find_by_code("eur").identifiers.map(&:id)).to include("cur:EUR")
    end

    it "returns nil for unknown codes" do
      expect(database.find_by_code("XXQ")).to be_nil
    end
  end

  describe "#find_by_numeric" do
    it "finds by ISO numeric identifier, zero-padded" do
      expect(database.find_by_numeric(978).identifiers.map(&:id)).to include("cur:EUR")
      expect(database.find_by_numeric("036").identifiers.map(&:id)).to include("cur:AUD")
    end

    it "returns nil for unknown numerics" do
      expect(database.find_by_numeric("000")).to be_nil
    end
  end

  describe "#find_by_symbol with currencies" do
    it "finds EUR by the euro sign" do
      ids = database.find_by_symbol("€", :currencies).flat_map { |entity| entity.identifiers.map(&:id) }
      expect(ids).to include("cur:EUR")
    end

    it "finds AUD by its unicode presentation" do
      ids = database.find_by_symbol("A$", :currencies).flat_map { |entity| entity.identifiers.map(&:id) }
      expect(ids).to include("cur:AUD")
    end

    it "leaves unit and prefix behavior untouched" do
      results = database.find_by_symbol("m")
      expect(results).to include(an_instance_of(Unitsdb::Unit), an_instance_of(Unitsdb::Prefix))
      expect(results).not_to include(an_instance_of(Unitsdb::Currency))
    end
  end
end
