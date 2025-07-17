# frozen_string_literal: true

require "spec_helper"
require "unitsdb/commands/normalize"
require "tempfile"
require "yaml"

RSpec.describe Unitsdb::Commands::Normalize do
  let(:command) { described_class.new(options) }
  let(:options) { { database: "./test_dir", sort: "short" } }

  # Create temporary files for testing
  let(:input_file) do
    file = Tempfile.new(["input", ".yaml"])
    file.close
    file
  end

  let(:output_file) do
    file = Tempfile.new(["output", ".yaml"])
    file.close
    file
  end

  let(:schema_2_yaml) do
    {
      "schema_version" => "2.0.0",
      "units" => [
        {
          "short" => "b_unit",
          "identifiers" => [
            { "id" => "id2", "type" => "type2" },
            { "id" => "nist2", "type" => "nist" },
            { "id" => "unitsml1", "type" => "unitsml" },
          ],
        },
        {
          "short" => "a_unit",
          "identifiers" => [
            { "id" => "id1", "type" => "type1" },
            { "id" => "nist1", "type" => "nist" },
            { "id" => "unitsml2", "type" => "unitsml" },
          ],
        },
      ],
    }
  end

  after do
    input_file.unlink
    output_file.unlink
  end

  describe "#run" do
    it "normalizes schema 2.0.0 YAML files correctly" do
      # Write test YAML to input file
      File.write(input_file.path, schema_2_yaml.to_yaml)

      # Run normalize command
      command.run(input_file.path, output_file.path)

      # Read the output file
      result = YAML.load_file(output_file.path)

      # Validate schema version is preserved
      expect(result["schema_version"]).to eq("2.0.0")

      # Validate units are sorted by short name
      expect(result["units"][0]["short"]).to eq("a_unit")
      expect(result["units"][1]["short"]).to eq("b_unit")
    end

    it "respects sort option when 'none' for schema 2.0.0" do
      # Create command with sort:'none'
      no_sort_command = described_class.new({ database: "./test_dir",
                                              sort: "none" })

      # Write test YAML to input file
      File.write(input_file.path, schema_2_yaml.to_yaml)

      # Run normalize command
      no_sort_command.run(input_file.path, output_file.path)

      # Read the output file and verify it's not sorted
      result = YAML.load_file(output_file.path)

      # Order should be unchanged
      expect(result["units"][0]["short"]).to eq("b_unit")
      expect(result["units"][1]["short"]).to eq("a_unit")
    end

    it "handles error for missing input/output without --all" do
      # Use StringIO to capture output
      original_stdout = $stdout
      output = StringIO.new
      $stdout = output

      # Stub exit to prevent test from actually exiting
      exit_called = false
      allow(command).to receive(:exit) { |code|
        exit_called = true
        code
      }

      # Run command with nil input/output
      command.run(nil, nil)

      # Reset stdout
      $stdout = original_stdout

      # Verify exit was called and error message was printed
      expect(exit_called).to be true
      expect(output.string).to include("Error: INPUT and OUTPUT are required when not using --all")
    end

    it "sorts by nist ID when sort option is 'nist'" do
      # Create command with sort:'nist'
      nist_sort_command = described_class.new({ database: "./test_dir",
                                                sort: "nist" })

      # Write test YAML to input file
      File.write(input_file.path, schema_2_yaml.to_yaml)

      # Run normalize command
      nist_sort_command.run(input_file.path, output_file.path)

      # Read the output file
      result = YAML.load_file(output_file.path)

      # Validate units are sorted by nist ID
      expect(result["units"][0]["identifiers"].find do |id|
        id["type"] == "nist"
      end["id"]).to eq("nist1")
      expect(result["units"][1]["identifiers"].find do |id|
        id["type"] == "nist"
      end["id"]).to eq("nist2")
    end

    it "sorts by unitsml ID when sort option is 'unitsml'" do
      # Create command with sort:'unitsml'
      unitsml_sort_command = described_class.new({ database: "./test_dir",
                                                   sort: "unitsml" })

      # Write test YAML to input file
      File.write(input_file.path, schema_2_yaml.to_yaml)

      # Run normalize command
      unitsml_sort_command.run(input_file.path, output_file.path)

      # Read the output file
      result = YAML.load_file(output_file.path)

      # Validate units are sorted by unitsml ID
      expect(result["units"][0]["identifiers"].find do |id|
        id["type"] == "unitsml"
      end["id"]).to eq("unitsml1")
      expect(result["units"][1]["identifiers"].find do |id|
        id["type"] == "unitsml"
      end["id"]).to eq("unitsml2")
    end

    it "handles --all option correctly" do
      # Create temp directory with sample files
      test_dir = Dir.mktmpdir
      begin
        # Create test YAML files
        default_files = Unitsdb::Utils::DEFAULT_YAML_FILES
        default_files.each do |file|
          File.write(File.join(test_dir, file), schema_2_yaml.to_yaml)
        end

        # Create command with --all option
        all_command = described_class.new({ all: true, database: test_dir,
                                            sort: "short" })

        # Capture standard output
        original_stdout = $stdout
        output = StringIO.new
        $stdout = output

        # Run command with --all option
        all_command.run

        # Reset stdout
        $stdout = original_stdout

        # Verify output for each file
        default_files.each do |file|
          path = File.join(test_dir, file)
          expect(output.string).to include("Normalized #{path}")

          # Check that files were actually sorted
          result = YAML.load_file(path)
          if result["units"] # Some files might have different collection keys
            expect(result["units"].map do |u|
              u["short"]
            end).to eq(result["units"].map { |u|
                      u["short"]
                    }.sort)
          end
        end

        expect(output.string).to include("All YAML files normalized successfully!")
      ensure
        # Clean up temp directory
        FileUtils.remove_entry(test_dir)
      end
    end
  end
end
