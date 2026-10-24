# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unitsdb::Currency do
  let(:database) do
    Unitsdb.reset_database_cache!
    Unitsdb.database
  end

  around do |example|
    Unitsdb.reset_database_cache!
    Lutaml::Model::GlobalContext.reset!
    example.run
  ensure
    Unitsdb.reset_database_cache!
    Lutaml::Model::GlobalContext.reset!
  end

  it "is registered for the lutaml type registry" do
    expect(Unitsdb::Config.registered_models[:currency]).to eq(described_class)
  end

  it "is exposed as a Database collection attribute" do
    expect(database.currencies).to be_an(Array)
  end

  context "with currencies in the bundled data" do
    before do
      pending("currencies.yaml not yet in the pinned data tag") if database.currencies.empty?
    end

    it "loads the euro with its identifiers" do
      eur = database.currencies.find do |currency|
        currency.identifiers.any? { |identifier| identifier.type == "iso4217" && identifier.id == "EUR" }
      end

      expect(eur.minor_unit_exponent).to eq(2)
      expect(eur.status).to eq("active")
      expect(eur.names.map(&:lang)).to include("en")
      expect(eur.identifiers.map(&:type))
        .to contain_exactly("iso4217", "iso4217_numeric", "unitsml")
    end

    it "carries provenance notes on special codes" do
      xag = database.currencies.find do |currency|
        currency.identifiers.any? { |identifier| identifier.type == "iso4217" && identifier.id == "XAG" }
      end

      expect(xag.notes).to include("troy ounce")
    end
  end
end
