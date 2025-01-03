# frozen_string_literal: true

RSpec.describe Unitsdb::Prefix do
  file_path = File.join(__dir__, "../fixtures/prefixes.yaml")
  prefixes_yaml = YAML.safe_load(IO.read(file_path))

  prefixes_yaml.each_pair do |key, value|
    prefix_hash = value
    it "parses the prefix #{key}" do
      prefix_yaml = prefix_hash.to_yaml
      prefix = described_class.from_yaml(prefix_yaml)
      expect(prefix.to_yaml).to be_yaml_equivalent_to(prefix_yaml)
    end
  end
end
