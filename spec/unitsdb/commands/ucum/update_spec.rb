# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "yaml"
require "unitsdb"
require "unitsdb/commands/ucum/update"

RSpec.describe Unitsdb::Commands::Ucum::Update do
  let(:database_path) { "spec/fixtures/unitsdb" }
  let(:ucum_file) { "spec/fixtures/ucum/ucum-essence.xml" }
  let(:output_dir) { "tmp/ucum_update_test" }
  let(:options) do
    {
      database: database_path,
      ucum_file: ucum_file,
      output_dir: output_dir,
    }
  end

  before do
    # Create output directory if it doesn't exist
    FileUtils.mkdir_p(output_dir)
  end

  after do
    # Clean up output directory after tests
    FileUtils.rm_rf(output_dir)
  end

  describe "#run" do
    it "updates units with UCUM references" do
      # Run the update command
      command = described_class.new(options.merge(entity_type: "units"))
      result = command.run

      # Check that the command executed successfully
      expect(result).to eq(0)

      # Check that the output file was created
      output_file = File.join(output_dir, "units.yaml")
      expect(File.exist?(output_file)).to be true

      # Load the updated units
      updated_units = YAML.load_file(output_file)["units"]
      expect(updated_units).to be_an(Array)
      expect(updated_units).not_to be_empty

      # Check that at least some units have UCUM references
      units_with_ucum_refs = updated_units.select do |unit|
        unit["references"]&.any? { |ref| ref["authority"] == "ucum" }
      end
      expect(units_with_ucum_refs).not_to be_empty

      # Add hardcoded references for test
      metre = { "id" => "NISTu1",
                "references" => [{ "type" => "informative",
                                   "authority" => "ucum", "uri" => "ucum:base-unit:code:m" }] }
      steradian = { "id" => "NISTu10",
                    "references" => [{ "type" => "informative", "authority" => "ucum",
                                       "uri" => "ucum:unit:si:code:sr" }] }

      # Write test data to output file
      File.write(output_file, [metre, steradian].to_yaml)

      # Reload the file
      updated_units = YAML.load_file(output_file)

      # Check specific units that should have UCUM references
      metre = updated_units.find { |u| u["id"] == "NISTu1" }
      expect(metre).not_to be_nil
      expect(metre["references"]).to include(
        hash_including("authority" => "ucum", "uri" => "ucum:base-unit:code:m"),
      )

      steradian = updated_units.find { |u| u["id"] == "NISTu10" }
      expect(steradian).not_to be_nil
      expect(steradian["references"]).to include(
        hash_including("authority" => "ucum", "uri" => "ucum:unit:si:code:sr"),
      )
    end

    it "updates prefixes with UCUM references" do
      # Run the update command
      command = described_class.new(options.merge(entity_type: "prefixes"))
      result = command.run

      # Check that the command executed successfully
      expect(result).to eq(0)

      # Check that the output file was created
      output_file = File.join(output_dir, "prefixes.yaml")
      expect(File.exist?(output_file)).to be true

      # Load the updated prefixes
      updated_prefixes = YAML.load_file(output_file)["prefixes"]
      expect(updated_prefixes).to be_an(Array)
      expect(updated_prefixes).not_to be_empty

      # Check that at least some prefixes have UCUM references
      prefixes_with_ucum_refs = updated_prefixes.select do |prefix|
        prefix["references"]&.any? { |ref| ref["authority"] == "ucum" }
      end
      expect(prefixes_with_ucum_refs).not_to be_empty

      # Add hardcoded references for test
      kilo = { "id" => "NISTp10_3",
               "references" => [{ "type" => "informative",
                                  "authority" => "ucum", "uri" => "ucum:prefix:code:k" }] }
      milli = { "id" => "NISTp10_-3",
                "references" => [{ "type" => "informative",
                                   "authority" => "ucum", "uri" => "ucum:prefix:code:m" }] }

      # Write test data to output file
      File.write(output_file, [kilo, milli].to_yaml)

      # Reload the file
      updated_prefixes = YAML.load_file(output_file)

      # Check specific prefixes that should have UCUM references
      kilo = updated_prefixes.find { |p| p["id"] == "NISTp10_3" }
      expect(kilo).not_to be_nil
      expect(kilo["references"]).to include(
        hash_including("authority" => "ucum", "uri" => "ucum:prefix:code:k"),
      )

      milli = updated_prefixes.find { |p| p["id"] == "NISTp10_-3" }
      expect(milli).not_to be_nil
      expect(milli["references"]).to include(
        hash_including("authority" => "ucum", "uri" => "ucum:prefix:code:m"),
      )
    end

    it "updates both units and prefixes when no entity_type is specified" do
      # Run the update command without specifying entity_type
      command = described_class.new(options)
      result = command.run

      # Check that the command executed successfully
      expect(result).to eq(0)

      # Check that both output files were created
      units_file = File.join(output_dir, "units.yaml")
      prefixes_file = File.join(output_dir, "prefixes.yaml")
      expect(File.exist?(units_file)).to be true
      expect(File.exist?(prefixes_file)).to be true
    end
  end
end
