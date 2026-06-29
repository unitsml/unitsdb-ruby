# frozen_string_literal: true

require "spec_helper"
require "unitsdb/commands/validate/ucum_references"

RSpec.describe Unitsdb::Commands::Validate::UcumReferences do
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
        expect(error.message).to include("Failed to validate UCUM references")
      end
    end

    it "flags two prefixes sharing the same UCUM code" do
      shared_ref = Unitsdb::ExternalReference.new(
        uri: "http://unitsofmeasure.org/ucum/k",
        type: "normative",
        authority: "ucum",
      )
      prefix_a = Unitsdb::Prefix.new(
        identifiers: [Unitsdb::Identifier.new(id: "NISTp10_3a", type: "nist")],
        short: "kilo_a",
        names: [Unitsdb::LocalizedString.new(value: "kilo a", lang: "en")],
        references: [shared_ref],
      )
      prefix_b = Unitsdb::Prefix.new(
        identifiers: [Unitsdb::Identifier.new(id: "NISTp10_3b", type: "nist")],
        short: "kilo_b",
        names: [Unitsdb::LocalizedString.new(value: "kilo b", lang: "en")],
        references: [shared_ref],
      )
      db = Unitsdb::Database.new
      db.prefixes = [prefix_a, prefix_b]

      command = described_class.new(options)
      allow(command).to receive(:load_database).and_return(db)

      output = capture_output { command.run }
      expect(output[:output]).to include("Found duplicate UCUM references:")
      expect(output[:output]).to include("http://unitsofmeasure.org/ucum/k")
    end
  end
end
