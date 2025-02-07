# frozen_string_literal: true

RSpec.describe Unitsdb::Dimensions::Dimension do
  file_path = File.join(__dir__, "../fixtures/dimensions.yaml")
  dimensions_yaml = YAML.safe_load(IO.read(file_path))

  dimensions_yaml.each_pair do |key, value|
    dimension_hash = value
    it "parses the dimension #{key}" do
      dimension_yaml = dimension_hash.to_yaml
      dimension = described_class.from_yaml(dimension_yaml)
      expect(dimension.to_yaml).to be_yaml_equivalent_to(dimension_yaml)
    end
  end
end
