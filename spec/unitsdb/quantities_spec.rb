# frozen_string_literal: true

RSpec.describe Unitsdb::Quantities do
  file_path = File.join(__dir__, "../fixtures/unitsdb/quantities.yaml")

  it "parses the quantity collection from the new array structure" do
    raw_string = IO.read(file_path)
    yaml_hash = { "quantities" => YAML.safe_load(raw_string) }
    parsed = described_class.from_yaml(yaml_hash.to_yaml)

    # Check the first quantity has expected fields
    first_quantity = parsed.quantities.first
    expect(first_quantity.identifiers).to be_an(Array)
    expect(first_quantity.identifiers).not_to be_empty
    expect(first_quantity.identifiers.first.id).not_to be_nil
    expect(first_quantity.identifiers.first.type).not_to be_nil

    expect(first_quantity.quantity_name).to be_an(Array)
    expect(first_quantity.quantity_type).not_to be_nil

    expect(first_quantity.unit_references).to be_an(Array)
    expect(first_quantity.unit_references).not_to be_empty
    expect(first_quantity.unit_references.first.id).not_to be_nil
    expect(first_quantity.unit_references.first.type).not_to be_nil

    expect(first_quantity.dimension_reference).not_to be_nil
    expect(first_quantity.dimension_reference.id).not_to be_nil
    expect(first_quantity.dimension_reference.type).not_to be_nil
  end
end
