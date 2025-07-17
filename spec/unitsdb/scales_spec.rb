# frozen_string_literal: true

RSpec.describe Unitsdb::Scales do
  file_path = File.join(__dir__, "../fixtures/unitsdb/scales.yaml")

  it "parses the scale collection from the new array structure" do
    raw_string = File.read(file_path)
    parsed = described_class.from_yaml(raw_string)
    generated = parsed.to_yaml

    # puts generated
    # puts raw_string
    expect(generated).to be_yaml_equivalent_to(raw_string)
  end
end
