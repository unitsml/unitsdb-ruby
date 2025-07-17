# frozen_string_literal: true

require "spec_helper"
require "unitsdb/commands/check_si"
require "stringio"

RSpec.describe Unitsdb::Commands::CheckSi do
  let(:command) { described_class.new(options) }
  let(:options) { { database: fixture_dir, ttl_dir: ttl_dir } }
  let(:output) { StringIO.new }
  let(:fixture_dir) do
    File.join(File.dirname(__FILE__), "../../fixtures/unitsdb")
  end
  let(:ttl_dir) do
    File.join(File.dirname(__FILE__), "../../fixtures/bipm-si-ttl")
  end

  before do
    # Redirect output for testing
    $stdout = output
  end

  after do
    # Restore standard output
    $stdout = STDOUT
  end

  describe "#check_si" do
    context "basic functionality" do
      let(:options) do
        {
          database: fixture_dir,
          ttl_dir: ttl_dir,
          entity_type: "units",
          direction: "both",
        }
      end

      it "processes the specified entity type in both directions" do
        expect(command).to receive(:check_from_si).once
        expect(command).to receive(:check_to_si).once
        command.run
      end
    end

    context "direction handling" do
      it "processes from_si direction only when specified" do
        cmd = described_class.new({
                                    database: fixture_dir,
                                    ttl_dir: ttl_dir,
                                    entity_type: "units",
                                    direction: "from_si",
                                  })

        expect(cmd).to receive(:check_from_si).once
        expect(cmd).not_to receive(:check_to_si)
        cmd.run
      end

      it "processes to_si direction only when specified" do
        cmd = described_class.new({
                                    database: fixture_dir,
                                    ttl_dir: ttl_dir,
                                    entity_type: "units",
                                    direction: "to_si",
                                  })

        expect(cmd).not_to receive(:check_from_si)
        expect(cmd).to receive(:check_to_si).once
        cmd.run
      end
    end
  end
end
