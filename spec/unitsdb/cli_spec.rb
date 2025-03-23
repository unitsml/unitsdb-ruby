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
      expect(Unitsdb::CLI.subcommand_classes["validate"]).to eq(Unitsdb::Commands::ValidateCommand)
    end
  end

  describe "#check_si_units" do
    it "delegates to the CheckSiUnits command" do
      expect_any_instance_of(Unitsdb::Commands::CheckSiUnits).to receive(:check).with(any_args)
      cli.options = { database: "test/db", ttl_dir: "test/ttl" }
      cli.check_si_units
    end

    it "passes options to the command" do
      options = {
        database: "test/db",
        ttl_dir: "test/ttl",
        entity_type: "quantities",
        output: "output.yaml"
      }
      expect_any_instance_of(Unitsdb::Commands::CheckSiUnits).to receive(:check).with(options)
      cli.options = options
      cli.check_si_units
    end
  end

  describe "removed commands" do
    it "does not have check_si_references command" do
      expect(Unitsdb::CLI.commands.keys).not_to include("check_si_references")
    end

    it "does not have check_si_refs command" do
      expect(Unitsdb::CLI.commands.keys).not_to include("check_si_refs")
    end
  end
end
