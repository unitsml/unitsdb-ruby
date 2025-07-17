# frozen_string_literal: true

require_relative "../../lib/unitsdb/unit_systems"

RSpec.describe Unitsdb::UnitSystems do
  file_path = File.join(__dir__, "../fixtures/unitsdb/unit_systems.yaml")

  it "parses the unit systems collection" do
    raw_string = File.read(file_path)
    parsed = described_class.from_yaml(raw_string)
    generated = parsed.to_yaml

    expect(generated).to be_yaml_equivalent_to(raw_string)
  end
end
