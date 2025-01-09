# frozen_string_literal: true

RSpec.describe Unitsdb::Units do
  file_path = File.join(__dir__, "../fixtures/units.yaml")

  it "parses the unit collection" do
    raw_string = IO.read(file_path)
    parsed = described_class.from_yaml(raw_string)
    generated = parsed.to_yaml

    # puts generated
    # puts raw_string
    expect(generated).to eq(raw_string)
  end
end
