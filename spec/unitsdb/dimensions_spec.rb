# frozen_string_literal: true

RSpec.describe Unitsdb::Dimensions do
  file_path = File.join(__dir__, "../fixtures/unitsdb/dimensions.yaml")

  it "parses the dimension collection" do
    raw_string = IO.read(file_path)
    yaml_hash = { "dimensions" => YAML.safe_load(raw_string) }
    new_yaml = yaml_hash.to_yaml
    parsed = described_class.from_yaml(new_yaml)
    generated = parsed.to_yaml

    # puts generated
    # puts raw_string
    expect(generated).to be_yaml_equivalent_to(new_yaml)
  end
end
