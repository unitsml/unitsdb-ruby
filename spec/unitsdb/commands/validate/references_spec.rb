# frozen_string_literal: true

require "spec_helper"
require "unitsdb/commands/validate/references"
require "fileutils"
require "yaml"

RSpec.describe Unitsdb::Commands::Validate::References do
  let(:fixtures_dir) { File.join("spec", "fixtures", "test_references") }
  let(:options) { { database: fixtures_dir } }
  let(:command) { described_class.new(options) }

  around do |example|
    FileUtils.mkdir_p(fixtures_dir)
    example.run
  ensure
    FileUtils.rm_rf(fixtures_dir)
  end

  describe "#run" do
    context "with a database whose references are all valid" do
      before do
        write_fixture(
          dimensions: [
            {
              "identifiers" => [{ "id" => "NISTd1", "type" => "nist" }],
              "short" => "L",
              "names" => [{ "value" => "length", "lang" => "en" }],
            },
          ],
          units: [
            {
              "identifiers" => [{ "id" => "NISTu1", "type" => "nist" }],
              "short" => "meter",
              "names" => [{ "value" => "meter", "lang" => "en" }],
              "dimension_reference" => { "id" => "NISTd1", "type" => "nist" },
              "unit_system_reference" => [{ "id" => "si-base",
                                            "type" => "unitsml" }],
            },
          ],
          unit_systems: [
            {
              "identifiers" => [{ "id" => "si-base", "type" => "unitsml" }],
              "short" => "SI",
              "names" => [{ "value" => "SI base", "lang" => "en" }],
            },
          ],
        )
      end

      it "reports that all references are valid" do
        output = capture_output { command.run }

        expect(output[:output]).to include("All references are valid!")
      end
    end

    context "with a database containing a broken unit_system_reference" do
      before do
        write_fixture(
          units: [
            {
              "identifiers" => [{ "id" => "NISTu1", "type" => "nist" }],
              "short" => "meter",
              "names" => [{ "value" => "meter", "lang" => "en" }],
              "unit_system_reference" => [{ "id" => "invalid-system",
                                            "type" => "unitsml" }],
            },
          ],
          unit_systems: [
            {
              "identifiers" => [{ "id" => "si-base", "type" => "unitsml" }],
              "short" => "SI",
              "names" => [{ "value" => "SI base", "lang" => "en" }],
            },
          ],
        )
      end

      it "reports the invalid reference path" do
        output = capture_output { command.run }

        expect(output[:output]).to include("Found invalid references:")
        expect(output[:output]).to include("units:index:0:unit_system_reference[0]")
      end
    end

    it "raises a ValidationError when the database cannot be loaded" do
      expect do
        described_class.new(database: "/does/not/exist").run
      end.to raise_error(Unitsdb::Errors::ValidationError)
    end
  end

  private

  def write_fixture(dimensions: [], units: [], unit_systems: [],
                    prefixes: [], quantities: [])
    {
      "dimensions" => dimensions,
      "units" => units,
      "unit_systems" => unit_systems,
      "prefixes" => prefixes,
      "quantities" => quantities,
    }.each do |name, payload|
      File.write(
        File.join(fixtures_dir, "#{name}.yaml"),
        { "schema_version" => "2.0.0", name => payload }.to_yaml,
      )
    end
  end
end
