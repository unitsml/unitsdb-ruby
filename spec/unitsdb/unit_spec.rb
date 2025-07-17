# frozen_string_literal: true

RSpec.describe Unitsdb::Unit do
  file_path = File.join(__dir__, "../fixtures/unitsdb/units.yaml")
  units_yaml = YAML.safe_load_file(file_path)["units"]

  units_yaml.each do |value|
    unit_hash = value
    it "parses the unit #{value['id']}" do
      unit_yaml = unit_hash.to_yaml
      unit = described_class.from_yaml(unit_yaml)
      expect(unit.to_yaml).to be_yaml_equivalent_to(unit_yaml)
    end
  end
end
