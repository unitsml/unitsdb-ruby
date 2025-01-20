# frozen_string_literal: true

RSpec.describe Unitsdb::Quantities::Quantity do
  file_path = File.join(__dir__, "../fixtures/quantities.yaml")
  quantities_yaml = YAML.safe_load(IO.read(file_path))

  quantities_yaml.each_pair do |key, value|
    quantity_hash = value
    it "parses the quantity #{key}" do
      quantity_yaml = quantity_hash.to_yaml
      quantity = described_class.from_yaml(quantity_yaml)
      expect(quantity.to_yaml).to be_yaml_equivalent_to(quantity_yaml)
    end
  end
end
