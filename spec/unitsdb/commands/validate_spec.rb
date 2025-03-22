# frozen_string_literal: true

require "spec_helper"
require "unitsdb/commands/validate"
require "stringio"

RSpec.describe Unitsdb::Commands::ValidateCommand do
  let(:validate_command) { described_class.new }

  # No global output capture - each test will capture output explicitly

  describe "subcommands" do
    it "has a references subcommand" do
      expect(described_class.subcommand_classes["references"]).to eq(Unitsdb::Commands::Validate::References)
    end

    it "has a uniqueness subcommand" do
      expect(described_class.subcommand_classes["uniqueness"]).to eq(Unitsdb::Commands::Validate::Uniqueness)
    end
  end
end
