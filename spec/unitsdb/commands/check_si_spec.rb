# frozen_string_literal: true

require "spec_helper"
require "unitsdb/commands/check_si"
require "stringio"

RSpec.describe Unitsdb::Commands::CheckSi do
  let(:command) { described_class.new(options) }
  let(:options) { { database: fixture_dir, ttl_dir: ttl_dir } }
  let(:output) { StringIO.new }
  let(:fixture_dir) { File.join(File.dirname(__FILE__), "../../fixtures/unitsdb") }
  let(:ttl_dir) { File.join(File.dirname(__FILE__), "../../fixtures/bipm-si-ttl") }

  before do
    # Redirect output for testing
    $stdout = output
  end

  after do
    # Restore standard output
    $stdout = STDOUT
  end

  describe "#check_si" do
    context "direction both" do
      let(:options) do
        {
          database: fixture_dir,
          ttl_dir: ttl_dir,
          direction: "both"
        }
      end

      it "processes all entity types when no entity_type is specified" do
        command.run
      end
    end

    context "when entity type is specified" do
      let(:options) do
        {
          database: fixture_dir,
          ttl_dir: ttl_dir,
          entity_type: "units",
          direction: "both"
        }
      end

      it "only processes the specified entity type" do
        command.run
      end
    end

    context "direction is from_si" do
      let(:options) do
        {
          database: fixture_dir,
          ttl_dir: ttl_dir,
          entity_type: "units",
          direction: "from_si"
        }
      end
      it "processes entities in from_si direction when specified" do
        # Should call check_from_si but not check_to_si
        expect(command).to receive(:check_from_si).once
        expect(command).not_to receive(:check_to_si)

        command.run
      end
    end

    context "direction is to_si" do
      # Set direction option
      let(:options) do
        {
          database: fixture_dir,
          ttl_dir: ttl_dir,
          entity_type: "units",
          direction: "to_si"
        }
      end
      it "processes entities in to_si direction when specified" do
        # Should call check_to_si but not check_from_si
        expect(command).not_to receive(:check_from_si)
        expect(command).to receive(:check_to_si).once

        command.run
      end
    end

    context "direction is nil (defaults to both)" do
      # Set direction option to nil (should default to both)
      let(:options) do
        {
          database: fixture_dir,
          ttl_dir: ttl_dir,
          entity_type: "units"
        }
      end
      it "processes entities in both directions by default" do
        # Should call both check methods
        expect(command).to receive(:check_from_si).once
        expect(command).to receive(:check_to_si).once

        command.run
      end
    end

    context "when output_updated_database is specified" do
      # Set output_updated_database option
      let(:options) do
        {
          database: fixture_dir,
          ttl_dir: ttl_dir,
          entity_type: "units",
          output_updated_database: "test_output"
        }
      end
      it "updates references when output_updated_database is specified" do
        command.run
      end
    end

    context "when output_updated_database is not specified" do
      # Set output_updated_database option to nil
      let(:options) do
        {
          database: fixture_dir,
          ttl_dir: ttl_dir,
          entity_type: "units"
        }
      end

      it "does not update references when output_updated_database is not specified" do
        # Should not call update methods
        expect(command).not_to receive(:update_references)
        expect(command).not_to receive(:update_db_references)

        command.run
      end
    end

    context "when include_potential_matches is specified" do
      # Set include_potential_matches option to true
      let(:options) do
        {
          database: fixture_dir,
          ttl_dir: ttl_dir,
          entity_type: "units",
          output_updated_database: "test_output",
          include_potential_matches: true
        }
      end

      it "includes potential matches when updating references" do
        # Should pass include_potential=true to update methods
        expect(command).to receive(:process_entity_type).with("units", anything, anything, anything, anything,
                                                              true).once
        command.run
      end
    end

    context "when include_potential_matches is not specified" do
      # Set include_potential_matches option to nil (defaults to false)
      let(:options) do
        {
          database: fixture_dir,
          ttl_dir: ttl_dir,
          entity_type: "units",
          output_updated_database: "test_output"
        }
      end

      it "does not include potential matches by default" do
        # Should pass include_potential=false to update methods
        expect(command).to receive(:process_entity_type).with("units", anything, anything, anything, anything,
                                                              false).once
        command.run
      end
    end
  end

  describe "#match_ttl_to_db and #match_db_to_ttl" do
    it "correctly matches entities and identifies missing references" do
      # Mock the entity types
      allow(command).to receive(:find_matching_entities).and_return([])

      # Test with empty entities
      result = command.send(:match_ttl_to_db, "units", [], [])
      expect(result).to eq([[], [], []])

      result = command.send(:match_db_to_ttl, "units", [], [])
      expect(result).to eq([[], [], []])

      # Test with actual entities (just a basic sanity check)
      ttl_entity = { uri: "http://test/uri", name: "test", label: "Test" }
      db_entity = double("entity").as_null_object

      allow(db_entity).to receive_message_chain(:identifiers, :first, :value).and_return("test-id")
      allow(db_entity).to receive(:references).and_return([])
      allow(command).to receive(:find_entity_id).and_return("test-id")
      allow(command).to receive(:find_matching_entities).and_return([db_entity])
      allow(command).to receive(:match_entity_names?).and_return({
                                                                   match: true,
                                                                   exact: true,
                                                                   match_type: "Exact match",
                                                                   match_desc: "short_to_name"
                                                                 })

      result = command.send(:match_ttl_to_db, "units", [ttl_entity], [db_entity])
      expect(result[0]).to eq([]) # No matches
      expect(result[1].size).to eq(1) # One missing match
      expect(result[2]).to eq([]) # No unmatched TTL entities

      result = command.send(:match_db_to_ttl, "units", [ttl_entity], [db_entity])
      expect(result[0]).to eq([]) # No matches
      expect(result[1].size).to eq(1) # One missing match
      expect(result[2]).to eq([]) # No unmatched db entities
    end
  end
end
