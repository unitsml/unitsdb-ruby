# frozen_string_literal: true

require "spec_helper"
require "unitsdb/commands/validate/qudt_references"

RSpec.describe Unitsdb::Commands::Validate::QudtReferences do
  let(:database_path) { "spec/fixtures/unitsdb" }
  let(:options) { { database: database_path } }

  describe "#run" do
    it "can be instantiated and run without errors" do
      command = described_class.new(options)

      # The command should be able to be instantiated
      expect(command).to be_a(described_class)

      # Should run without raising an exception
      expect { command.run }.not_to raise_error
    end

    it "loads the database correctly" do
      command = described_class.new(options)

      # Should not raise an error when loading the database
      expect { command.run }.not_to raise_error
    end

    it "handles database errors gracefully" do
      invalid_options = { database: "/nonexistent/path" }
      command = described_class.new(invalid_options)

      # Should exit with error code 1 for invalid database path
      expect { command.run }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(1)
      end
    end

    it "validates QUDT references across all entity types" do
      command = described_class.new(options)

      # Mock the database to have entities with QUDT references
      db = double("database")
      allow(command).to receive(:load_database).and_return(db)

      # Mock entities with no references (should pass validation)
      units = [double("unit", references: nil)]
      quantities = [double("quantity", references: [])]
      dimensions = [double("dimension", references: nil)]
      unit_systems = [double("unit_system", references: [])]

      allow(db).to receive_messages(units: units, quantities: quantities,
                                    dimensions: dimensions, unit_systems: unit_systems)

      # Should run without errors
      expect { command.run }.not_to raise_error
    end
  end
end
