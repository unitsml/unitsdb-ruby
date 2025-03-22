# frozen_string_literal: true

require_relative "../../lib/unitsdb/prefixes"

RSpec.describe Unitsdb::Prefixes do
  file_path = File.join(__dir__, "../fixtures/unitsdb/prefixes.yaml")

  it "parses the prefix collection" do
    raw_string = IO.read(file_path)
    parsed = described_class.from_yaml(raw_string)
    generated = parsed.to_yaml

    # puts generated
    # puts raw_string
    expect(generated).to be_yaml_equivalent_to(raw_string)
  end
end
