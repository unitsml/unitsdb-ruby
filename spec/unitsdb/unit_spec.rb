# frozen_string_literal: true

RSpec.describe Unitsdb::Unit do
  file_path = File.join(__dir__, "../fixtures/units.yaml")
  units_yaml = YAML.safe_load(IO.read(file_path))

  units_yaml.each_pair do |key, value|
    unit_hash = value
    it "parses the unit #{key}" do
      unit_yaml = unit_hash.to_yaml
      unit = Unitsdb::Unit.from_yaml(unit_yaml)
      expect(unit.to_yaml).to be_yaml_equivalent_to(unit_yaml)
    end
  end
end
