# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unitsdb::Database do
  let(:fixtures_dir) { File.join("spec", "fixtures", "unitsdb") }
  let(:database) { described_class.from_db(fixtures_dir) }

  describe "search and lookup functionality" do
    it "finds entities using search by text with type filters" do
      # Generic text search
      results = database.search(text: "meter")
      expect(results).not_to be_empty
      expect(results.any?(Unitsdb::Unit)).to be(true)

      # Search with type filter
      results = database.search(text: "kilo", type: "prefixes")
      expect(results.all?(Unitsdb::Prefix)).to be(true)

      # Handling non-existent terms and nil values
      expect(database.search(text: "nonexistentterm123456")).to be_empty
      expect(database.search(text: nil)).to be_empty
    end

    it "finds entities by id and type" do
      # Find by specific type
      entity = database.find_by_type(id: "NISTu1", type: "units")
      expect(entity).to be_a(Unitsdb::Unit)

      # Returns nil for non-existent entities
      expect(database.find_by_type(id: "NonExistentID",
                                   type: "units")).to be_nil

      # Find by id across all types
      entity = database.get_by_id(id: "NISTu1")
      expect(entity).to be_a(Unitsdb::Unit)

      # Find with identifier type filter
      entity = database.get_by_id(id: "NISTu1", type: "nist")
      expect(entity).to be_a(Unitsdb::Unit)

      # Returns nil for non-existent IDs or wrong types
      expect(database.get_by_id(id: "NonExistentID")).to be_nil
      expect(database.get_by_id(id: "NISTu1", type: "wrong_type")).to be_nil
    end
  end
end
