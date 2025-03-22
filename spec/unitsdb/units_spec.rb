# frozen_string_literal: true

require_relative "../../lib/unitsdb/units"

RSpec.describe Unitsdb::Units do
  file_path = File.join(__dir__, "../fixtures/unitsdb/units.yaml")

  it "parses the unit collection" do
    raw_string = IO.read(file_path)
    yaml_hash = { "units" => YAML.safe_load(raw_string) }
    new_yaml = yaml_hash.to_yaml
    parsed = described_class.from_yaml(new_yaml)
    generated = parsed.to_yaml

    expect(generated).to be_yaml_equivalent_to(new_yaml)
  end
end
