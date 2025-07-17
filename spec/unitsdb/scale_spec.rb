# frozen_string_literal: true

RSpec.describe Unitsdb::Scale do
  file_path = File.join(__dir__, "../fixtures/unitsdb/scales.yaml")
  scales_yaml = YAML.safe_load_file(file_path)

  scales_yaml["scales"].each do |scale_hash|
    identifier = scale_hash["identifiers"]&.first || {}
    id = identifier["id"]

    it "parses the scale #{id}" do
      scale_yaml = scale_hash.to_yaml
      scale = described_class.from_yaml(scale_yaml)
      expect(scale.to_yaml).to be_yaml_equivalent_to(scale_yaml)
    end
  end
end
