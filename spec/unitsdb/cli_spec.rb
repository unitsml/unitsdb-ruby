# frozen_string_literal: true

require "spec_helper"
require "unitsdb/cli"
require "stringio"

RSpec.describe Unitsdb::CLI do
  let(:cli) { described_class.new }

  # No global output capture - each test will capture output explicitly

  describe "#check_uniqueness" do
    it "delegates to the Uniqueness command" do
      expect_any_instance_of(Unitsdb::Commands::Uniqueness).to receive(:check).with(nil, {})
      cli.check_uniqueness
    end

    it "passes options to the command" do
      expect_any_instance_of(Unitsdb::Commands::Uniqueness).to receive(:check).with("input.yaml",
                                                                                    { all: true, dir: "test_dir" })
      cli.options = { all: true, dir: "test_dir" }
      cli.check_uniqueness("input.yaml")
    end
  end

  describe "#normalize" do
    it "delegates to the Normalize command" do
      expect_any_instance_of(Unitsdb::Commands::Normalize).to receive(:yaml).with(nil, nil, {})
      cli.normalize
    end

    it "passes input, output, and options to the command" do
      expect_any_instance_of(Unitsdb::Commands::Normalize).to receive(:yaml).with("input.yaml", "output.yaml",
                                                                                  { sort: true, all: true, dir: "test_dir" })
      cli.options = { sort: true, all: true, dir: "test_dir" }
      cli.normalize("input.yaml", "output.yaml")
    end
  end

  describe "validate subcommand" do
    it "registers the ValidateCommand as a subcommand" do
      expect(Unitsdb::CLI.subcommand_classes["validate"]).to eq(Unitsdb::Commands::ValidateCommand)
    end
  end
end
