# frozen_string_literal: true

require "spec_helper"

RSpec.describe "unitsdb executable" do
  let(:executable_path) { File.expand_path("../../exe/unitsdb", __dir__) }

  it "exists and is executable" do
    expect(File.exist?(executable_path)).to be true
    expect(File.executable?(executable_path)).to be true
  end

  it "contains the correct shebang line" do
    first_line = File.open(executable_path, &:readline).strip
    expect(first_line).to eq("#!/usr/bin/env ruby")
  end

  it "requires the correct files" do
    content = File.read(executable_path)
    expect(content).to include('require "unitsdb"')
    expect(content).to include('require "unitsdb/cli"')
  end

  it "calls CLI.start with ARGV" do
    content = File.read(executable_path)
    expect(content).to include("Unitsdb::CLI.start(ARGV)")
  end

  # This tests that the executable code structure matches what we expect
  # This is a more robust test than testing behavior with mocks
  it "contains code that calls CLI.start with ARGV" do
    content = File.read(executable_path)
    # Check that the last significant line is the CLI.start call
    significant_lines = content.lines.map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
    expect(significant_lines.last).to eq("Unitsdb::CLI.start(ARGV)")
  end
end
