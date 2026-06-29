# frozen_string_literal: true

require "spec_helper"
require "unitsdb/commands/validate/qudt_references"

RSpec.describe Unitsdb::Commands::Validate::QudtReferences do
  let(:database_path) { "data" }
  let(:options) { { database: database_path } }

  describe "#run" do
    it "runs against the bundled database without raising" do
      expect { capture_output { described_class.new(options).run } }.not_to raise_error
    end

    it "raises ValidationError when the database path is missing" do
      expect do
        described_class.new(database: "/nonexistent/path").run
      end.to raise_error(Unitsdb::Errors::ValidationError) do |error|
        expect(error.message).to include("Failed to validate QUDT references")
      end
    end

    it "flags two units sharing the same QUDT URI" do
      shared_ref = Unitsdb::ExternalReference.new(
        uri: "http://qudt.org/vocab/unit/M",
        type: "normative",
        authority: "qudt",
      )
      unit_a = Unitsdb::Unit.new(
        identifiers: [Unitsdb::Identifier.new(id: "NISTu1", type: "nist")],
        short: "meter_a",
        names: [Unitsdb::LocalizedString.new(value: "meter a", lang: "en")],
        references: [shared_ref],
      )
      unit_b = Unitsdb::Unit.new(
        identifiers: [Unitsdb::Identifier.new(id: "NISTu2", type: "nist")],
        short: "meter_b",
        names: [Unitsdb::LocalizedString.new(value: "meter b", lang: "en")],
        references: [shared_ref],
      )
      db = Unitsdb::Database.new
      db.units = [unit_a, unit_b]

      command = described_class.new(options)
      allow(command).to receive(:load_database).and_return(db)

      output = capture_output { command.run }
      expect(output[:output]).to include("Found duplicate QUDT references:")
      expect(output[:output]).to include("http://qudt.org/vocab/unit/M")
    end
  end
end
