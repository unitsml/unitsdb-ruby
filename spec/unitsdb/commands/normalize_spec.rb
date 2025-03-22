# frozen_string_literal: true

require "spec_helper"
require "unitsdb/commands/normalize"
require "stringio"
require "tempfile"

RSpec.describe Unitsdb::Commands::Normalize do
  let(:command) { described_class.new }
  let(:mock_options) { { dir: "./test_dir", sort: true } }
  let(:test_yaml) { { "key2" => "value2", "key1" => "value1" } }
  let(:normalized_yaml) { { "key1" => "value1", "key2" => "value2" } }

  # No global output capture - each test will capture output explicitly

  before do
    # Mock yaml loading and Utils sort functionality
    allow(command).to receive(:load_yaml).and_return(test_yaml)
    allow(Unitsdb::Utils).to receive(:sort_yaml_keys).and_return(normalized_yaml)
    allow(File).to receive(:write)
    # Allow exit to be stubbed
    allow(command).to receive(:exit)
  end

  describe "#yaml" do
    context "with input and output files" do
      it "normalizes the YAML file" do
        expect(Unitsdb::Utils).to receive(:sort_yaml_keys).with(test_yaml).and_return(normalized_yaml)
        expect(File).to receive(:write).with("output.yaml", anything)

        command.yaml("input.yaml", "output.yaml", mock_options)
        expect(command).to have_received(:load_yaml).with("input.yaml")
      end

      it "outputs a success message" do
        output = capture_output do
          command.yaml("input.yaml", "output.yaml", mock_options)
        end
        expect(output[:output]).to include("Normalized YAML written to output.yaml")
      end

      it "respects the sort option" do
        # When sort is false, should not sort keys
        mock_options_no_sort = { dir: "./test_dir", sort: false }

        expect(Unitsdb::Utils).not_to receive(:sort_yaml_keys)
        expect(File).to receive(:write).with("output.yaml", anything)

        command.yaml("input.yaml", "output.yaml", mock_options_no_sort)
      end
    end

    context "with --all option" do
      # Use the actual list from Utils module to ensure test is in sync with implementation
      let(:default_files) { Unitsdb::Utils::DEFAULT_YAML_FILES }

      before do
        allow(Unitsdb::Utils).to receive(:DEFAULT_YAML_FILES).and_return(default_files)
        allow(File).to receive(:exist?).and_return(true)
      end

      it "processes all default YAML files" do
        # Instead of expecting specific files in a specific order, just count the calls
        expect(command).to receive(:normalize_file).exactly(default_files.length).times

        command.yaml(nil, nil, { all: true, dir: "./test_dir", sort: true })
      end

      it "outputs success messages for each file" do
        output = capture_output do
          command.yaml(nil, nil, { all: true, dir: "./test_dir", sort: true })
        end
        default_files.each do |file|
          file_path = File.join("./test_dir", file)
          expect(output[:output]).to include("Normalized #{file_path}")
        end
        expect(output[:output]).to include("All YAML files normalized successfully!")
      end

      it "skips files that don't exist" do
        # Set up file existence mocks
        default_files.each_with_index do |file, index|
          # Make half the files exist and half not exist
          allow(File).to receive(:exist?).with(File.join("./test_dir", file)).and_return(index.even?)
        end

        # Count how many files should exist (even-indexed files)
        existing_files_count = (default_files.length + 1) / 2

        # Should only normalize the files that exist
        expect(command).to receive(:normalize_file).exactly(existing_files_count).times

        command.yaml(nil, nil, { all: true, dir: "./test_dir", sort: true })
      end
    end

    context "with invalid arguments" do
      it "exits with an error when input and output are missing and --all is not specified" do
        expect(command).to receive(:exit).with(1)
        command.yaml(nil, nil, mock_options)
        expect(command).not_to receive(:normalize_file)
      end

      it "exits with a helpful error message" do
        output = capture_output do
          command.yaml(nil, nil, mock_options)
        end
        expect(output[:output]).to include("Error: INPUT and OUTPUT are required when not using --all")
      end
    end
  end

  describe "#normalize_file" do
    it "loads, processes, and writes the YAML file" do
      expect(command).to receive(:load_yaml).with("input.yaml").and_return(test_yaml)
      expect(Unitsdb::Utils).to receive(:sort_yaml_keys).with(test_yaml).and_return(normalized_yaml)
      expect(File).to receive(:write).with("output.yaml", normalized_yaml.to_yaml)

      command.send(:normalize_file, "input.yaml", "output.yaml", mock_options)
    end
  end
end
