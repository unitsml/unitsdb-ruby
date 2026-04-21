# frozen_string_literal: true

require "fileutils"
require "tmpdir"

RSpec.describe Unitsdb::Database do
  let(:dir_path) { File.expand_path("../../data", __dir__) }
  let(:database_files) do
    %w[prefixes.yaml dimensions.yaml units.yaml quantities.yaml unit_systems.yaml]
  end

  it "parses the full unitsdb database" do
    parsed = described_class.from_db(dir_path)
    generated = parsed.to_yaml

    prefixes_hash = YAML.safe_load_file(File.join(dir_path,
                                                  "prefixes.yaml"))
    dimensions_hash = YAML.safe_load_file(File.join(dir_path,
                                                    "dimensions.yaml"))
    units_hash = YAML.safe_load_file(File.join(dir_path, "units.yaml"))
    quantities_hash = YAML.safe_load_file(File.join(dir_path,
                                                    "quantities.yaml"))
    unit_systems_hash = YAML.safe_load_file(File.join(dir_path,
                                                      "unit_systems.yaml"))

    prefixes_version = prefixes_hash["schema_version"]

    combined_yaml = {
      "schema_version" => prefixes_version,
      "prefixes" => prefixes_hash["prefixes"],
      "dimensions" => dimensions_hash["dimensions"],
      "units" => units_hash["units"],
      "quantities" => quantities_hash["quantities"],
      "unit_systems" => unit_systems_hash["unit_systems"],
    }.to_yaml

    # puts generated
    # puts raw_string
    expect(generated).to be_yaml_equivalent_to(combined_yaml)
  end

  it "does not write to stdout during a normal load" do
    original_debug = ENV.fetch("DEBUG", nil)
    ENV.delete("DEBUG")

    output = capture_output { described_class.from_db(dir_path) }

    expect(output[:output]).to eq("")
  ensure
    ENV["DEBUG"] = original_debug
  end

  it "raises a helpful error when a database YAML file is not a mapping" do
    Dir.mktmpdir do |tmpdir|
      copy_database_files(tmpdir)
      File.write(File.join(tmpdir, "units.yaml"), ["invalid"].to_yaml)

      expect do
        described_class.from_db(tmpdir)
      end.to raise_error(
        Unitsdb::Errors::DatabaseFileInvalidError,
        /Invalid YAML structure in units\.yaml: expected a mapping/,
      )
    end
  end

  it "raises a helpful error when a collection key is missing" do
    Dir.mktmpdir do |tmpdir|
      copy_database_files(tmpdir)

      units_file = File.join(tmpdir, "units.yaml")
      units_hash = YAML.safe_load_file(units_file)
      units_hash.delete("units")
      File.write(units_file, units_hash.to_yaml)

      expect do
        described_class.from_db(tmpdir)
      end.to raise_error(
        Unitsdb::Errors::DatabaseFileInvalidError,
        /Missing units collection in units\.yaml/,
      )
    end
  end

  it "raises a helpful error when schema_version is missing" do
    Dir.mktmpdir do |tmpdir|
      copy_database_files(tmpdir)
      update_database_file(tmpdir, "units.yaml") do |units_hash|
        units_hash.delete("schema_version")
      end

      expect do
        described_class.from_db(tmpdir)
      end.to raise_error(
        Unitsdb::Errors::DatabaseFileInvalidError,
        /Missing schema_version in units\.yaml/,
      )
    end
  end

  it "raises a helpful error when schema versions do not match" do
    Dir.mktmpdir do |tmpdir|
      copy_database_files(tmpdir)
      update_database_file(tmpdir, "quantities.yaml") do |quantities_hash|
        quantities_hash["schema_version"] = "2.0.1"
      end

      expect do
        described_class.from_db(tmpdir)
      end.to raise_error(
        Unitsdb::Errors::VersionMismatchError,
        /Version mismatch in database files: .*"quantities\.yaml"\s*=>\s*"2\.0\.1"/,
      )
    end
  end

  it "raises a helpful error when schema version is unsupported" do
    Dir.mktmpdir do |tmpdir|
      copy_database_files(tmpdir)
      database_files.each do |filename|
        update_database_file(tmpdir, filename) do |document|
          document["schema_version"] = "3.0.0"
        end
      end

      expect do
        described_class.from_db(tmpdir)
      end.to raise_error(
        Unitsdb::Errors::UnsupportedVersionError,
        /Unsupported database version: 3\.0\.0\. Only version 2\.0\.0 is supported\./,
      )
    end
  end

  def copy_database_files(target_dir)
    database_files.each do |filename|
      FileUtils.cp(File.join(dir_path, filename), File.join(target_dir, filename))
    end
  end

  def update_database_file(tmpdir, filename)
    file_path = File.join(tmpdir, filename)
    document = YAML.safe_load_file(file_path)
    yield document
    File.write(file_path, document.to_yaml)
  end
end
