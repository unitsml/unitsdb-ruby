# frozen_string_literal: true

RSpec.describe Unitsdb::Unit do
  file_path = File.join(__dir__, "../fixtures/units.yaml")
  units_yaml = YAML.load(IO.read(file_path))

  it "parses a unit" do
    key, unit_yaml = units_yaml.first

    unit = Unitsdb::Unit.from_yaml(unit_yaml.to_yaml)

    #   "NISTu1":
    # dimension_url: "#NISTd1"
    # short: meter
    # root: true
    # unit_system:
    #   type: "SI_base"
    #   name: "SI"
    # unit_name:
    #   - "meter"
    # unit_symbols:
    #   - id: "m"
    #     ascii: "m"
    #     html: "m"
    #     mathml: "<mi mathvariant='normal'>m</mi>"
    #     latex: \ensuremath{\mathrm{m}}
    #     unicode: "m"
    # root_units:
    #   enumerated_root_units:
    #     - unit: "meter"
    #       power_denominator: 1
    #       power_numerator: 1

    expect(unit.short).to eq("meter")
    expect(unit.root).to eq(true)
    expect(unit.dimension_url).to eq("#NISTd1")
    # expect(unit.unit_system).to eq()
    expect(unit.unit_name.first).to eq("meter")
  end
end
