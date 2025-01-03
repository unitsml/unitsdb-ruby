# frozen_string_literal: true

RSpec.describe Unitsdb::UnitSystem do
  file_path = File.join(__dir__, "../fixtures/unit_systems.yaml")
  unit_systems_yaml = YAML.safe_load(IO.read(file_path))

  unit_systems_yaml.each do |value|
    it "parses the unit_system #{value[:id]}" do
      unit_system_yaml = value.to_yaml
      unit = described_class.from_yaml(unit_system_yaml)
      expect(unit.to_yaml).to be_yaml_equivalent_to(unit_system_yaml)
    end
  end
end
