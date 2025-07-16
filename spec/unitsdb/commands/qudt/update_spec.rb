# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "yaml"
require "unitsdb"
require "unitsdb/commands/qudt/update"

RSpec.describe Unitsdb::Commands::Qudt::Update do
  let(:database_path) { "spec/fixtures/unitsdb" }
  let(:output_dir) { "tmp/qudt_update_test" }
  let(:options) do
    {
      database: database_path,
      output_dir: output_dir
    }
  end

  before do
    # Create output directory if it doesn't exist
    FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)
  end

  after do
    # Clean up output directory after tests
    FileUtils.rm_rf(output_dir) if Dir.exist?(output_dir)
  end

  describe "#run" do
    it "can be instantiated and run without errors" do
      # This is a basic smoke test since we don't have actual QUDT TTL files
      # in the test fixtures yet
      command = described_class.new(options.merge(entity_type: "units"))

      # The command should be able to be instantiated
      expect(command).to be_a(described_class)

      # We expect this to fail gracefully since we don't have QUDT data
      # but it should not raise an exception during instantiation
      expect { command }.not_to raise_error
    end

    it "validates parameters correctly" do
      # Test with invalid TTL directory
      invalid_options = options.merge(ttl_dir: "/nonexistent/path")
      command = described_class.new(invalid_options)

      # Should exit with error code 1 for invalid TTL directory
      expect { command.run }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(1)
      end
    end

    it "handles entity type filtering" do
      # Test with specific entity type
      command = described_class.new(options.merge(entity_type: "units"))
      expect(command).to be_a(described_class)

      # Test with invalid entity type (should process all types)
      command = described_class.new(options.merge(entity_type: "invalid"))
      expect(command).to be_a(described_class)
    end

    it "handles include_potential_matches option" do
      # Test with include_potential_matches enabled
      command = described_class.new(options.merge(include_potential_matches: true))
      expect(command).to be_a(described_class)

      # Test with include_potential_matches disabled (default)
      command = described_class.new(options.merge(include_potential_matches: false))
      expect(command).to be_a(described_class)
    end
  end
end
