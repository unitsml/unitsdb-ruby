# frozen_string_literal: true

require_relative "../../lib/unitsdb/units"

RSpec.describe Unitsdb::Units do
  file_path = File.join(__dir__, "../fixtures/unitsdb/units.yaml")

  it "parses the unit collection" do
    raw_string = File.read(file_path)
    parsed = described_class.from_yaml(raw_string)
    generated = parsed.to_yaml

    expect(generated).to be_yaml_equivalent_to(raw_string)
  end
end
