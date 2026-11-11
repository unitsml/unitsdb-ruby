# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Unitsdb::Database do
  around do |example|
    Dir.mktmpdir("unitsdb-scale-loader") do |directory|
      @directory = directory
      described_class::Loader::REQUIRED_DATABASE_FILES.each do |collection, filename|
        File.write(File.join(directory, filename), { "schema_version" => "2.2.0", collection => [] }.to_yaml)
      end
      example.run
    end
  end

  def write_collection(collection, values, version: "2.2.0")
    File.write(File.join(@directory, "#{collection}.yaml"),
               { "schema_version" => version, collection => values }.to_yaml)
  end

  it "keeps scale files optional for older data directories" do
    database = described_class.from_db(@directory)

    expect(database.scales).to eq([])
    expect(database.schema_version).to eq("2.2.0")
  end

  it "loads ordered scales and preserves exact conversion and quantity fields" do
    # Synthetic structural data; these identifiers make no physical-constant claims.
    write_collection("scales", [
                       { "identifiers" => [{ "id" => "test-scale-b", "type" => "test" }],
                         "properties" => { "continuous" => false, "ordered" => true },
                         "operations" => ["difference", "comparison"] },
                       { "identifiers" => [{ "id" => "test-scale-a", "type" => "test" }],
                         "operations" => ["comparison"] },
                     ])
    write_collection("quantities", [{ "identifiers" => [{ "id" => "test-q", "type" => "test" }],
                                      "equivalence_class" => "test-equivalence" }])
    write_collection("units", [{ "identifiers" => [{ "id" => "test-u", "type" => "test" }],
                                 "scale_reference" => { "id" => "test-scale-b", "type" => "test" },
                                 "quantity_references" => [{ "id" => "test-q", "type" => "test", "primary" => false }],
                                 "canonical_conversion" => { "factor" => "1/3", "offset" => "0.0000000000000000001" } }])
    database = described_class.from_db(@directory)

    expect(database.scales.map { |scale| scale.identifiers.first.id }).to eq(%w[test-scale-b test-scale-a])
    expect(database.scales.first.properties.continuous).to be(false)
    expect(database.scales.first.operations).to eq(%w[difference comparison])
    expect(database.get_by_id(id: "test-scale-b")).to equal(database.scales.first)
    expect(database.quantities.first.equivalence_class).to eq("test-equivalence")
    unit = database.get_by_id(id: "test-u")
    expect(unit.scale_reference.id).to eq("test-scale-b")
    expect(unit.quantity_references.first.primary).to be(false)
    expect(unit.canonical_conversion.factor).to eq("1/3")
    expect(unit.canonical_conversion.offset).to eq("0.0000000000000000001")
  end

  it "checks the schema version of an optional scales file" do
    write_collection("scales", [], version: "2.0.0")

    expect { described_class.from_db(@directory) }.to raise_error(Unitsdb::Errors::VersionMismatchError)
  end
end
