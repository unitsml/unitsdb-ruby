# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "yaml"
require "zip"
require "unitsdb/commands/base"
require "unitsdb/commands/release"

RSpec.describe Unitsdb::Commands::Release do
  let(:database_path) { "spec/fixtures/unitsdb" }
  let(:output_dir) { "tmp/release_test" }
  let(:release_version) { "2.0.0" }
  let(:options) { { database: database_path, output_dir: output_dir, version: release_version } }
  let(:schema_version) { YAML.load_file(File.join(database_path, "units.yaml"))["schema_version"] }

  before do
    FileUtils.mkdir_p(output_dir)
  end

  after do
    FileUtils.rm_rf(output_dir)
  end

  describe "#run" do
    context "with default options (all formats)" do
      it "creates both unified YAML and ZIP archive" do
        command = described_class.new(options)
        expect { command.run }.not_to raise_error

        # Check unified YAML file
        yaml_path = File.join(output_dir, "unitsdb-#{release_version}.yaml")
        expect(File.exist?(yaml_path)).to be true

        # Verify YAML content
        yaml_content = YAML.load_file(yaml_path)
        expect(yaml_content["schema_version"]).to eq(schema_version)
        expect(yaml_content["version"]).to eq(release_version)
        expect(yaml_content["units"]).to be_a(Array)
        expect(yaml_content["quantities"]).to be_a(Array)
        expect(yaml_content["dimensions"]).to be_a(Array)
        expect(yaml_content["prefixes"]).to be_a(Array)
        expect(yaml_content["unit_systems"]).to be_a(Array)

        # Check ZIP archive
        zip_path = File.join(output_dir, "unitsdb-#{release_version}.zip")
        expect(File.exist?(zip_path)).to be true

        # Verify ZIP content
        file_list = []
        Zip::File.open(zip_path) do |zip|
          zip.each { |entry| file_list << entry.name }
        end

        expect(file_list).to include("units.yaml")
        expect(file_list).to include("quantities.yaml")
        expect(file_list).to include("dimensions.yaml")
        expect(file_list).to include("prefixes.yaml")
        expect(file_list).to include("unit_systems.yaml")
      end
    end

    context "with yaml format only" do
      let(:options) { { database: database_path, output_dir: output_dir, format: "yaml", version: release_version } }

      it "creates only unified YAML file" do
        command = described_class.new(options)
        expect { command.run }.not_to raise_error

        # Check unified YAML file exists
        yaml_path = File.join(output_dir, "unitsdb-#{release_version}.yaml")
        expect(File.exist?(yaml_path)).to be true

        # Check ZIP archive doesn't exist
        zip_path = File.join(output_dir, "unitsdb-#{release_version}.zip")
        expect(File.exist?(zip_path)).to be false
      end
    end

    context "with zip format only" do
      let(:options) { { database: database_path, output_dir: output_dir, format: "zip", version: release_version } }

      it "creates only ZIP archive" do
        command = described_class.new(options)
        expect { command.run }.not_to raise_error

        # Check unified YAML file doesn't exist
        yaml_path = File.join(output_dir, "unitsdb-#{release_version}.yaml")
        expect(File.exist?(yaml_path)).to be false

        # Check ZIP archive exists
        zip_path = File.join(output_dir, "unitsdb-#{release_version}.zip")
        expect(File.exist?(zip_path)).to be true
      end
    end

    context "with custom version" do
      let(:custom_version) { "v2.1.0" }
      let(:options) { { database: database_path, output_dir: output_dir, version: custom_version } }

      it "creates files with custom version in filename" do
        command = described_class.new(options)
        expect { command.run }.not_to raise_error

        # Check unified YAML file with custom version
        yaml_path = File.join(output_dir, "unitsdb-#{custom_version}.yaml")
        expect(File.exist?(yaml_path)).to be true

        # Check ZIP archive with custom version
        zip_path = File.join(output_dir, "unitsdb-#{custom_version}.zip")
        expect(File.exist?(zip_path)).to be true

        # Verify YAML content still has original schema_version and custom version
        yaml_content = YAML.load_file(yaml_path)
        expect(yaml_content["schema_version"]).to eq(schema_version)
        expect(yaml_content["version"]).to eq(custom_version)
      end
    end

    context "with missing files" do
      let(:invalid_path) { "spec/fixtures/nonexistent" }
      let(:options) { { database: invalid_path, output_dir: output_dir, version: release_version } }

      it "exits with an error" do
        command = described_class.new(options)
        expect { command.run }.to raise_error(SystemExit)
      end
    end

    context "with inconsistent schema versions" do
      let(:temp_db_path) { "tmp/inconsistent_db" }
      let(:options) { { database: temp_db_path, output_dir: output_dir, version: release_version } }

      before do
        FileUtils.mkdir_p(temp_db_path)

        # Copy original files
        Unitsdb::Utils::DEFAULT_YAML_FILES.each do |file|
          FileUtils.cp(File.join(database_path, file), File.join(temp_db_path, file))
        end

        # Modify one file to have a different schema version
        units_file = File.join(temp_db_path, "units.yaml")
        units_yaml = YAML.load_file(units_file)
        units_yaml["schema_version"] = "inconsistent-version"
        File.write(units_file, units_yaml.to_yaml)
      end

      after do
        FileUtils.rm_rf(temp_db_path)
      end

      it "exits with an error" do
        command = described_class.new(options)
        expect { command.run }.to raise_error(SystemExit)
      end
    end
  end
end
