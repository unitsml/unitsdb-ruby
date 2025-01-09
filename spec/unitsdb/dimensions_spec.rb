# frozen_string_literal: true

RSpec.describe Unitsdb::Dimensions do
  file_path = File.join(__dir__, "../fixtures/dimensions.yaml")

  it "parses the dimension collection" do
    raw_string = IO.read(file_path)
    parsed = described_class.from_yaml(raw_string)
    generated = parsed.to_yaml

    # puts generated
    # puts raw_string
    expect(generated).to eq(raw_string)
  end
end
