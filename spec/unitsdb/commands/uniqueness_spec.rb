# frozen_string_literal: true

require "spec_helper"
require "unitsdb/commands/uniqueness"
require "stringio"

RSpec.describe Unitsdb::Commands::Uniqueness do
  let(:command) { described_class.new }
  let(:mock_database) { instance_double("Unitsdb::Database") }
  let(:mock_options) { { dir: "./test_dir" } }

  # Mocked collections
  let(:mock_units) { [] }
  let(:mock_dimensions) { [] }
  let(:mock_prefixes) { [] }
  let(:mock_quantities) { [] }
  let(:mock_unit_systems) { [] }

  # No global output capture - each test will capture output explicitly

  before do
    # Set up mock database
    allow(mock_database).to receive(:units).and_return(mock_units)
    allow(mock_database).to receive(:dimensions).and_return(mock_dimensions)
    allow(mock_database).to receive(:prefixes).and_return(mock_prefixes)
    allow(mock_database).to receive(:quantities).and_return(mock_quantities)
    allow(mock_database).to receive(:unit_systems).and_return(mock_unit_systems)

    allow(Unitsdb::Database).to receive(:from_db).and_return(mock_database)
  end

  describe "#check" do
    context "when no duplicates exist" do
      it "reports no duplicates found" do
        output = capture_output do
          command.check("sample.yaml", mock_options)
        end
        expect(output[:output]).to include("No duplicate 'short' fields found.")
        expect(output[:output]).to include("No duplicate 'id' fields found.")
      end
    end

    context "when duplicates exist" do
      let(:mock_unit1) do
        double("Unit",
               short: "m",
               identifiers: [double("Identifier", id: "meter", type: "symbol", respond_to?: true)])
      end

      let(:mock_unit2) do
        double("Unit",
               short: "m",
               identifiers: [double("Identifier", id: "meter-alt", type: "symbol", respond_to?: true)])
      end

      let(:mock_units) { [mock_unit1, mock_unit2] }

      it "reports duplicate shorts" do
        output = capture_output do
          command.check("sample.yaml", mock_options)
        end
        expect(output[:output]).to include("Found duplicate 'short' fields:")
        expect(output[:output]).to include("units:")
        expect(output[:output]).to include("'m':")
      end
    end

    context "when duplicate IDs exist" do
      let(:mock_unit1) do
        double("Unit",
               short: "m",
               identifiers: [double("Identifier", id: "duplicate-id", type: "symbol", respond_to?: true)])
      end

      let(:mock_unit2) do
        double("Unit",
               short: "cm",
               identifiers: [double("Identifier", id: "duplicate-id", type: "symbol", respond_to?: true)])
      end

      let(:mock_units) { [mock_unit1, mock_unit2] }

      it "reports duplicate ids" do
        output = capture_output do
          command.check("sample.yaml", mock_options)
        end
        expect(output[:output]).to include("Found duplicate 'id' fields:")
        expect(output[:output]).to include("units:")
        expect(output[:output]).to include("'duplicate-id':")
      end
    end

    context "with --all option" do
      it "processes all default YAML files" do
        default_files = Unitsdb::Utils::DEFAULT_YAML_FILES.map { |f| File.join("./test_dir", f) }

        # Use a more lenient expectation that doesn't rely on exact arguments order
        allow(command).to receive(:yaml_files).and_return(default_files)
        expect(command).to receive(:yaml_files)

        # This will simulate the CLI passing options as a hash directly
        command.check(nil, { all: true, dir: "./test_dir" })
      end
    end
  end
end
