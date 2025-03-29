# frozen_string_literal: true

require "spec_helper"
require "unitsdb/commands/normalize"
require "stringio"
require "tempfile"

RSpec.describe Unitsdb::Commands::Normalize do
  let(:command) { described_class.new(options) }
  let(:options) { { database: "./test_dir", sort: true } }
  let(:test_yaml) { { "key2" => "value2", "key1" => "value1" } }
  let(:normalized_yaml) { { "key1" => "value1", "key2" => "value2" } }

  before do
    # Mock yaml loading and Utils sort functionality
    allow(command).to receive(:load_yaml).and_return(test_yaml)
    allow(Unitsdb::Utils).to receive(:sort_yaml_keys).and_return(normalized_yaml)
    allow(File).to receive(:write)
    allow(command).to receive(:exit)
  end

  describe "#run" do
    it "normalizes YAML files with proper input/output handling" do
      # Test single file normalization
      expect(Unitsdb::Utils).to receive(:sort_yaml_keys).with(test_yaml).and_return(normalized_yaml)
      expect(File).to receive(:write).with("output.yaml", anything)
      command.run("input.yaml", "output.yaml")

      # Test success message
      output = capture_output do
        command.run("input.yaml", "output.yaml")
      end
      expect(output[:output]).to include("Normalized YAML written to output.yaml")

      # Test respecting sort option when false
      no_sort_command = described_class.new({ database: "./test_dir", sort: false })
      allow(no_sort_command).to receive(:load_yaml).and_return(test_yaml)
      allow(no_sort_command).to receive(:exit)
      expect(Unitsdb::Utils).not_to receive(:sort_yaml_keys)
      no_sort_command.run("input.yaml", "output.yaml")

      # Test error for missing input/output without --all
      expect(command).to receive(:exit).with(1)
      output = capture_output do
        command.run(nil, nil)
      end
      expect(output[:output]).to include("Error: INPUT and OUTPUT are required when not using --all")
    end

    it "handles --all option correctly" do
      # Setup for --all option tests
      default_files = %w[dimensions.yaml prefixes.yaml quantities.yaml unit_systems.yaml units.yaml]
      all_command = described_class.new({ all: true, database: "./test_dir", sort: true })
      allow(all_command).to receive(:load_yaml).and_return(test_yaml)
      allow(Unitsdb::Utils).to receive(:DEFAULT_YAML_FILES).and_return(default_files)
      allow(File).to receive(:exist?).and_return(true)

      # Test processing all files when they exist
      expect(all_command).to receive(:normalize_file).exactly(default_files.length).times
      all_command.run(nil, nil)

      # Test skipping non-existent files
      default_files.each_with_index do |file, index|
        allow(File).to receive(:exist?).with(File.join("./test_dir", file)).and_return(index.even?)
      end
      existing_files_count = (default_files.length + 1) / 2
      expect(all_command).to receive(:normalize_file).exactly(existing_files_count).times
      all_command.run(nil, nil)
    end
  end
end
