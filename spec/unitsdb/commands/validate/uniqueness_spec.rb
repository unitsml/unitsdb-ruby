# frozen_string_literal: true

require "spec_helper"
require "unitsdb/commands/validate/uniqueness"
require "stringio"

RSpec.describe Unitsdb::Commands::Validate::Uniqueness do
  let(:command) { described_class.new }

  # No global output capture - each test will capture output explicitly

  describe "#check" do
    it "delegates to the Uniqueness command" do
      # The Validate::Uniqueness command simply delegates to the main Uniqueness command
      # So we just need to test that it does this delegation correctly
      expect_any_instance_of(Unitsdb::Commands::Uniqueness).to receive(:check).with("input.yaml", command.options)
      command.check("input.yaml")
    end

    it "passes options to the main Uniqueness command" do
      command.options = { dir: "test_dir", all: true }
      expect_any_instance_of(Unitsdb::Commands::Uniqueness).to receive(:check).with("input.yaml",
                                                                                    { dir: "test_dir", all: true })
      command.check("input.yaml")
    end

    it "works with nil input (when --all is used)" do
      command.options = { all: true, dir: "test_dir" }
      expect_any_instance_of(Unitsdb::Commands::Uniqueness).to receive(:check).with(nil, { all: true, dir: "test_dir" })
      command.check(nil)
    end
  end
end
