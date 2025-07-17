# frozen_string_literal: true

require "spec_helper"
require "unitsdb/commands/validate/si_references"

RSpec.describe Unitsdb::Commands::Validate::SiReferences do
  let(:options) do
    {
      database: "spec/fixtures/unitsdb",
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

  describe "#run" do
    it "checks for duplicate SI references" do
      command.run
      output_text = output.string

      # The test database shouldn't have duplicate SI references
      expect(output_text).to include("No duplicate SI references found!")
      expect(output_text).to include("Each SI reference URI is used by at most one entity of each type.")
    end

    context "with database parameter" do
      it "accepts a database path parameter" do
        command.run
        output_text = output.string

        # The test database shouldn't have duplicate SI references
        expect(output_text).to include("No duplicate SI references found!")
        expect(output_text).to include("Each SI reference URI is used by at most one entity of each type.")
      end
    end
  end
end
