# frozen_string_literal: true

RSpec.describe Unitsdb::Dimension do
  file_path = File.join(__dir__, "../fixtures/unitsdb/dimensions.yaml")
  dimensions_yaml = YAML.safe_load_file(file_path)

  dimensions_yaml["dimensions"].each do |value|
    it "parses the dimension #{value[:id]}" do
      dimension_yaml = value.to_yaml
      dimension = described_class.from_yaml(dimension_yaml)
      expect(dimension.to_yaml).to be_yaml_equivalent_to(dimension_yaml)
    end
  end
end
