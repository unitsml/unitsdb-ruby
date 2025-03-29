# frozen_string_literal: true

require "spec_helper"
require "unitsdb/commands/validate/identifiers"

RSpec.describe Unitsdb::Commands::Validate::Identifiers do
  let(:options) do
    {
      database: "spec/fixtures/unitsdb"
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
    it "validates identifier uniqueness" do
      command.run
      output_text = output.string

      # The test database shouldn't have duplicate identifiers
      expect(output_text).to include("No duplicate 'short' fields found.")
      expect(output_text).to include("No duplicate 'id' fields found.")
    end

    context "with database parameter" do
      it "accepts a database path parameter" do
        command.run
        output_text = output.string

        # The test database shouldn't have duplicate identifiers
        expect(output_text).to include("No duplicate 'short' fields found.")
        expect(output_text).to include("No duplicate 'id' fields found.")
      end
    end
  end
end
