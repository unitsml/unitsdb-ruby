# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unitsdb::Database do
  let(:fixtures_dir) { File.join("spec", "fixtures", "unitsdb") }
  let(:database) { Unitsdb::Database.from_db(fixtures_dir) }

  describe "#search" do
    context "when searching by text" do
      it "finds entities containing the text in identifiers, names, or descriptions" do
        results = database.search(text: "meter")
        expect(results).not_to be_empty
        expect(results.any? { |entity| entity.is_a?(Unitsdb::Unit) }).to be(true)
      end

      it "returns an empty array when no matches are found" do
        results = database.search(text: "nonexistentterm123456")
        expect(results).to be_empty
      end

      it "returns an empty array when text is nil" do
        results = database.search(text: nil)
        expect(results).to be_empty
      end

      it "filters results by entity type when specified" do
        results = database.search(text: "kilo", type: "prefixes")
        expect(results.all? { |entity| entity.is_a?(Unitsdb::Prefix) }).to be(true)
      end
    end
  end

  describe "#find_by_type" do
    it "finds an entity by its id and type" do
      entity = database.find_by_type(id: "NISTu1", type: "units")
      expect(entity).not_to be_nil
      expect(entity).to be_a(Unitsdb::Unit)
    end

    it "returns nil when no entity matches the id and type" do
      entity = database.find_by_type(id: "NonExistentID", type: "units")
      expect(entity).to be_nil
    end
  end

  describe "#get_by_id" do
    it "finds an entity by its id across all entity types" do
      entity = database.get_by_id(id: "NISTu1")
      expect(entity).not_to be_nil
      expect(entity).to be_a(Unitsdb::Unit)
    end

    it "filters by identifier type when specified" do
      entity = database.get_by_id(id: "NISTu1", type: "nist")
      expect(entity).not_to be_nil
      expect(entity).to be_a(Unitsdb::Unit)
    end

    it "returns nil when no entity matches the id" do
      entity = database.get_by_id(id: "NonExistentID")
      expect(entity).to be_nil
    end

    it "returns nil when entity matches id but not type" do
      # Create a test id that exists but with wrong type
      entity = database.get_by_id(id: "NISTu1", type: "wrong_type")
      expect(entity).to be_nil
    end
  end
end
