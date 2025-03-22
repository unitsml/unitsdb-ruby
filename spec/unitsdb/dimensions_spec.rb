# frozen_string_literal: true

RSpec.describe Unitsdb::Dimensions do
  file_path = File.join(__dir__, "../fixtures/unitsdb/dimensions.yaml")

  it "parses the dimension collection" do
    raw_string = IO.read(file_path)
    parsed = described_class.from_yaml(raw_string)
    generated = parsed.to_yaml

    expect(generated).to be_yaml_equivalent_to(raw_string)
  end
end
