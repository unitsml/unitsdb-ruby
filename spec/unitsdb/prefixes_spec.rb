# frozen_string_literal: true

require_relative "../../lib/unitsdb/prefixes"

RSpec.describe Unitsdb::Prefixes do
  file_path = File.join(__dir__, "../fixtures/unitsdb/prefixes.yaml")

  it "parses the prefix collection" do
    raw_string = IO.read(file_path)
    yaml_hash = { "prefixes" => YAML.safe_load(raw_string) }
    new_yaml = yaml_hash.to_yaml
    parsed = described_class.from_yaml(new_yaml)
    generated = parsed.to_yaml

    # puts generated
    # puts raw_string
    expect(generated).to be_yaml_equivalent_to(new_yaml)
  end
end
