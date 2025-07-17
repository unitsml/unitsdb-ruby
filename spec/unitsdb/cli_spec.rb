# frozen_string_literal: true

require "spec_helper"
require "unitsdb/cli"
require "stringio"

RSpec.describe Unitsdb::CLI do
  let(:cli) { described_class.new }

  # No global output capture - each test will capture output explicitly

  # normalize is now a subcommand under _modify
  # The original normalize tests are no longer applicable

  describe "validate subcommand" do
    it "registers the ValidateCommand as a subcommand" do
      expect(described_class.subcommand_classes["validate"]).to eq(Unitsdb::Commands::ValidateCommand)
    end
  end
end
