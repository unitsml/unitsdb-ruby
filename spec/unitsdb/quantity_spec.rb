# frozen_string_literal: true

RSpec.describe Unitsdb::Quantity do
  file_path = File.join(__dir__, "../fixtures/unitsdb/quantities.yaml")
  quantities_yaml = YAML.safe_load(IO.read(file_path))

  quantities_yaml.each do |quantity_hash|
    identifier = quantity_hash["identifiers"]&.first || {}
    id = identifier["id"]

    it "parses the quantity #{id}" do
      quantity_yaml = quantity_hash.to_yaml
      quantity = described_class.from_yaml(quantity_yaml)
      expect(quantity.to_yaml).to be_yaml_equivalent_to(quantity_yaml)
    end
  end
end
