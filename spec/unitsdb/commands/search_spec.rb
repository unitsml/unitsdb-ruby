# frozen_string_literal: true

require "spec_helper"
require "unitsdb/commands/search"
require "fileutils"

RSpec.describe Unitsdb::Commands::Search do
  let(:fixtures_dir) { File.join("spec", "fixtures", "unitsdb") }
  let(:instance) { described_class.new }

  describe "#search" do
    context "when searching for text" do
      it "finds matching entities" do
        # Redirect stdout to capture output
        original_stdout = $stdout
        output = StringIO.new
        $stdout = output

        # Execute search
        instance.search("meter", dir: fixtures_dir)

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
        instance.search("nonexistentterm123456", dir: fixtures_dir)

        # Reset stdout
        $stdout = original_stdout

        # Verify output indicates no results
        expect(output.string).to include("No results found")
      end
    end

    context "when specifying entity type" do
      it "limits search to that type" do
        # Redirect stdout to capture output
        original_stdout = $stdout
        output = StringIO.new
        $stdout = output

        # Execute search with type constraint
        instance.search("kilo", type: "prefixes", dir: fixtures_dir)

        # Reset stdout
        $stdout = original_stdout

        # Verify output contains expected content
        expect(output.string).to include("Prefix")
      end
    end

    context "when searching by id" do
      it "finds the entity with the matching id" do
        # Redirect stdout to capture output
        original_stdout = $stdout
        output = StringIO.new
        $stdout = output

        # Execute search with ID
        instance.search("meter", id: "NISTu1", dir: fixtures_dir)

        # Reset stdout
        $stdout = original_stdout

        # Verify output contains expected content
        expect(output.string).to include("Found entity:")
        expect(output.string).to include("Unit")
        expect(output.string).to include("NISTu1")
        expect(output.string).to include("Identifiers:")
      end
    end

    context "when searching by id with type filter" do
      it "finds the entity with the matching id and type" do
        # Redirect stdout to capture output
        original_stdout = $stdout
        output = StringIO.new
        $stdout = output

        # Execute search with ID and ID type
        instance.search("meter", id: "NISTu1", id_type: "nist", dir: fixtures_dir)

        # Reset stdout
        $stdout = original_stdout

        # Verify output contains expected content
        expect(output.string).to include("Found entity:")
      end
    end

    context "when searching by id that doesn't exist" do
      it "indicates that no entity was found" do
        # Redirect stdout to capture output
        original_stdout = $stdout
        output = StringIO.new
        $stdout = output

        # Execute search with non-existent ID
        instance.search("meter", id: "NonExistentID", dir: fixtures_dir)

        # Reset stdout
        $stdout = original_stdout

        # Verify output contains expected content
        expect(output.string).to include("No entity found with ID")
      end
    end

    context "when an error occurs" do
      it "handles the error gracefully" do
        # Create a test database that will raise an error when loaded
        allow(instance).to receive(:load_database).and_raise(StandardError.new("Test error"))

        # Expect exit to be called with status 1
        expect(instance).to receive(:exit).with(1)

        # Redirect stdout to capture output
        original_stdout = $stdout
        output = StringIO.new
        $stdout = output

        # Execute search
        expect { instance.search("test", dir: fixtures_dir) }.to output(/Error searching database: Test error/).to_stdout

        # Reset stdout
        $stdout = original_stdout
      end
    end
  end
end
