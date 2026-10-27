# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Unitsdb::Database::Loader do
  let(:data_dir) { File.expand_path("../../../data", __dir__) }
  let(:legacy_dir) do
    dir = File.join(Dir.mktmpdir, "legacy-data")
    Dir.mkdir(dir)
    described_class::REQUIRED_DATABASE_FILES.each_value do |filename|
      FileUtils.cp(File.join(data_dir, filename), File.join(dir, filename))
    end
    dir
  end

  after { FileUtils.rm_rf(legacy_dir) }

  it "loads a directory without currencies.yaml with an empty collection" do
    database = described_class.load(legacy_dir)

    expect(database["schema_version"]).to eq("2.1.0")
    expect(database["currencies"]).to eq([])
  end

  it "keeps the required-file error behavior intact" do
    File.delete(File.join(legacy_dir, "units.yaml"))

    expect { described_class.load(legacy_dir) }
      .to raise_error(Unitsdb::Errors::DatabaseFileNotFoundError, /units\.yaml/)
  end

  it "still rejects a present currencies.yaml whose version disagrees" do
    File.write(File.join(legacy_dir, "currencies.yaml"),
               <<~YAML)
                 schema_version: "1.1.0"
                 currencies: []
               YAML

    expect { described_class.load(legacy_dir) }
      .to raise_error(Unitsdb::Errors::VersionMismatchError)
  end

  it "accepts a present currencies.yaml at the supported version" do
    File.write(File.join(legacy_dir, "currencies.yaml"),
               <<~YAML)
                 schema_version: "2.1.0"
                 currencies: []
               YAML

    expect(described_class.load(legacy_dir)).to have_key("currencies")
  end
end
