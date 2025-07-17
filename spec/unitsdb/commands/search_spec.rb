# frozen_string_literal: true

require "spec_helper"
require "unitsdb/commands/search"
require "fileutils"

RSpec.describe Unitsdb::Commands::Search do
  let(:fixtures_dir) { File.join("spec", "fixtures", "unitsdb") }
  let(:command) { described_class.new(options) }
  let(:options) { { database: fixtures_dir } }

  describe "#search" do
    context "when searching for text" do
      it "finds matching entities" do
        # Redirect stdout to capture output
        original_stdout = $stdout
        output = StringIO.new
        $stdout = output

        # Execute search
        command.run("meter")

        # Reset stdout
        $stdout = original_stdout

        # Verify output contains expected content
        expect(output.string).to include("Found")
        expect(output.string).to include("Unit")
      end
    end

    context "when searching for non-existent text" do
      it "returns no results" do
        # Redirect stdout to capture output
        original_stdout = $stdout
        output = StringIO.new
        $stdout = output

        # Execute search with a term unlikely to exist
        command.run("nonexistentterm123456")

        # Reset stdout
        $stdout = original_stdout

        # Verify output indicates no results
        expect(output.string).to include("No results found")
      end
    end

    context "when specifying entity type" do
      let(:options) { { database: fixtures_dir, type: "prefixes" } }

      it "limits search to that type" do
        # Redirect stdout to capture output
        original_stdout = $stdout
        output = StringIO.new
        $stdout = output

        # Execute search with type constraint
        command.run("kilo")

        # Reset stdout
        $stdout = original_stdout

        # Verify output contains expected content
        expect(output.string).to include("Prefix")
      end
    end

    context "when searching by id" do
      let(:options) { { database: fixtures_dir, id: "NISTu1" } }

      it "finds the entity with the matching id" do
        # Redirect stdout to capture output
        original_stdout = $stdout
        output = StringIO.new
        $stdout = output

        # Execute search with ID
        command.run("meter")

        # Reset stdout
        $stdout = original_stdout

        # Verify output contains expected content
        expect(output.string).to include("Entity details:")
        expect(output.string).to include("Unit")
        expect(output.string).to include("NISTu1")
        expect(output.string).to include("Identifiers:")
      end
    end

    context "when searching by id with type filter" do
      let(:options) do
        { database: fixtures_dir, id: "NISTu1", id_type: "nist" }
      end

      it "finds the entity with the matching id and type" do
        # Redirect stdout to capture output
        original_stdout = $stdout
        output = StringIO.new
        $stdout = output

        # Execute search with ID and ID type
        command.run("meter")

        # Reset stdout
        $stdout = original_stdout

        # Verify output contains expected content
        expect(output.string).to include("Entity details:")
      end
    end

    context "when searching by id that doesn't exist" do
      let(:options) { { database: fixtures_dir, id: "NonExistentID" } }

      it "indicates that no entity was found" do
        # Redirect stdout to capture output
        original_stdout = $stdout
        output = StringIO.new
        $stdout = output

        # Execute search with non-existent ID
        command.run("meter")

        # Reset stdout
        $stdout = original_stdout

        # Verify output contains expected content
        expect(output.string).to include("No entity found with ID")
      end
    end

    context "when an error occurs" do
      it "handles the error gracefully" do
        # Create a test database that will raise an error when loaded
        allow(command).to receive(:load_database).and_raise(
          Unitsdb::Errors::DatabaseError, "Test error"
        )

        # Expect exit to be called with status 1
        expect(command).to receive(:exit).with(1)

        # Redirect stdout to capture output
        original_stdout = $stdout
        output = StringIO.new
        $stdout = output

        # Execute search
        expect { command.run("test") }.to output(/Test error/).to_stdout

        # Reset stdout
        $stdout = original_stdout
      end
    end
  end
end
