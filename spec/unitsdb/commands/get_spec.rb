# frozen_string_literal: true

require "spec_helper"
require "unitsdb/commands/get"

RSpec.describe Unitsdb::Commands::Get do
  let(:options) do
    {
      database: "spec/fixtures/unitsdb",
      format: "text",
    }
  end

  let(:command) { described_class.new(options) }
  let(:output) { StringIO.new }

  before do
    # Redirect stdout for testing output
    $stdout = output
  end

  after do
    # Reset stdout
    $stdout = STDOUT
  end

  describe "#get" do
    context "when entity is found" do
      it "displays unit details correctly" do
        # Using a unit ID that actually exists in the test database
        command.get("NISTu1")
        output_text = output.string

        expect(output_text).to include("Entity details:")
        expect(output_text).to include("Type: Unit")
        expect(output_text).to include("Name:")
      end

      it "displays prefix details correctly" do
        # Using a prefix ID that exists in test DB
        command.get("NISTp10_3")
        output_text = output.string

        expect(output_text).to include("Entity details:")
        expect(output_text).to include("Type: Prefix")
      end

      it "supports JSON output format" do
        options[:format] = "json"
        command.get("NISTu1")
        output_text = output.string

        expect(output_text).to include('"short":')
        expect(output_text).to include('"identifiers":')
      end

      it "supports YAML output format" do
        options[:format] = "yaml"
        command.get("NISTu1")
        output_text = output.string

        expect(output_text).to include("short:")
        expect(output_text).to include("identifiers:")
      end
    end

    context "when entity is not found" do
      it "displays an appropriate message" do
        command.get("nonexistententity1234")
        output_text = output.string

        expect(output_text).to include("No entity found with ID: 'nonexistententity1234'")
      end
    end
  end
end
