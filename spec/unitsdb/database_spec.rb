# frozen_string_literal: true

RSpec.describe Unitsdb::Database do
  dir_path = File.join(__dir__, "../fixtures/unitsdb/")

  it "parses the full unitsdb database" do
    parsed = described_class.from_db(dir_path)
    generated = parsed.to_yaml

    prefixes_hash = YAML.safe_load(IO.read(File.join(dir_path, "prefixes.yaml")))
    dimensions_hash = YAML.safe_load(IO.read(File.join(dir_path, "dimensions.yaml")))
    units_hash = YAML.safe_load(IO.read(File.join(dir_path, "units.yaml")))
    quantities_hash = YAML.safe_load(IO.read(File.join(dir_path, "quantities.yaml")))
    unit_systems_hash = YAML.safe_load(IO.read(File.join(dir_path, "unit_systems.yaml")))

    combined_yaml = {
      "prefixes" => prefixes_hash["prefixes"],
      "dimensions" => dimensions_hash["dimensions"],
      "units" => units_hash["units"],
      "quantities" => quantities_hash["quantities"],
      "unit_systems" => unit_systems_hash["unit_systems"]
    }.to_yaml

    # puts generated
    # puts raw_string
    expect(generated).to be_yaml_equivalent_to(combined_yaml)
  end
end
