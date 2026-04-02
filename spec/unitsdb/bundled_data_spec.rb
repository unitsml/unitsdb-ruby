# frozen_string_literal: true

RSpec.describe Unitsdb do
  describe ".data_dir" do
    it "returns a path to the bundled data directory" do
      expect(described_class.data_dir).to be_a(String)
      expect(described_class.data_dir).not_to be_empty
    end

    it "returns a path that exists on disk" do
      expect(File.directory?(described_class.data_dir)).to be true
    end

    it "returns a path containing the expected YAML data files" do
      expect(File.exist?(File.join(described_class.data_dir,
                                   "units.yaml"))).to be true
      expect(File.exist?(File.join(described_class.data_dir,
                                   "prefixes.yaml"))).to be true
      expect(File.exist?(File.join(described_class.data_dir,
                                   "dimensions.yaml"))).to be true
      expect(File.exist?(File.join(described_class.data_dir,
                                   "quantities.yaml"))).to be true
      expect(File.exist?(File.join(described_class.data_dir,
                                   "unit_systems.yaml"))).to be true
      expect(File.exist?(File.join(described_class.data_dir,
                                   "scales.yaml"))).to be true
    end

    it "returns the same path as the git submodule location" do
      # The submodule is at the repo root as `data/`
      expect(described_class.data_dir).to match(%r{/data$})
    end
  end

  describe ".database" do
    it "returns a pre-loaded Database instance" do
      db = described_class.database
      expect(db).to be_a(Unitsdb::Database)
    end

    it "loads all entity collections" do
      db = described_class.database
      expect(db.units).to be_a(Array)
      expect(db.prefixes).to be_a(Array)
      expect(db.dimensions).to be_a(Array)
      expect(db.quantities).to be_a(Array)
      expect(db.unit_systems).to be_a(Array)
    end

    it "has a valid schema version" do
      db = described_class.database
      expect(db.schema_version).to eq("2.0.0")
    end

    it "populates units with known entities" do
      db = described_class.database
      unit_ids = db.units.flat_map { |u| u.identifiers.map(&:id) }.compact.uniq
      expect(unit_ids).to include("NISTu1") # meter
    end

    it "populates prefixes with known entities" do
      db = described_class.database
      prefix_ids = db.prefixes.flat_map do |p|
        p.identifiers.map(&:id)
      end.compact.uniq
      expect(prefix_ids).to include("NISTp10_3") # kilo
    end

    it "populates dimensions with known entities" do
      db = described_class.database
      dimension_ids = db.dimensions.flat_map do |d|
        d.identifiers.map(&:id)
      end.compact.uniq
      expect(dimension_ids).to include("NISTd1") # length
    end

    it "populates quantities with known entities" do
      db = described_class.database
      quantity_ids = db.quantities.flat_map do |q|
        q.identifiers.map(&:id)
      end.compact.uniq
      expect(quantity_ids).to include("NISTq1") # length
    end

    it "populates unit_systems with known entities" do
      db = described_class.database
      system_ids = db.unit_systems.flat_map do |s|
        s.identifiers.map(&:id)
      end.compact.uniq
      expect(system_ids).to include("SI_base") # SI
    end

    it "has non-empty collections" do
      db = described_class.database
      expect(db.units).not_to be_empty
      expect(db.prefixes).not_to be_empty
      expect(db.dimensions).not_to be_empty
      expect(db.quantities).not_to be_empty
      expect(db.unit_systems).not_to be_empty
    end

    it "caches the database instance" do
      db1 = described_class.database
      db2 = described_class.database
      expect(db1.object_id).to eq(db2.object_id)
    end
  end

  describe "YAML file integrity" do
    let(:data_dir) { described_class.data_dir }

    it "all YAML files have schema_version 2.0.0" do
      %w[prefixes dimensions units quantities unit_systems].each do |entity|
        file_path = File.join(data_dir, "#{entity}.yaml")
        hash = YAML.safe_load_file(file_path)
        expect(hash["schema_version"]).to eq("2.0.0"),
                                          "Expected #{entity}.yaml to have schema_version 2.0.0, got #{hash['schema_version']}"
      end
    end

    it "all YAML files have their top-level key as an Array" do
      %w[prefixes dimensions units quantities unit_systems].each do |entity|
        file_path = File.join(data_dir, "#{entity}.yaml")
        hash = YAML.safe_load_file(file_path)
        expect(hash[entity]).to be_a(Array),
                                "Expected #{entity}.yaml[:#{entity}] to be an Array"
      end
    end

    it "units.yaml contains the meter entity" do
      file_path = File.join(data_dir, "units.yaml")
      hash = YAML.safe_load_file(file_path)
      meter = hash["units"].find do |u|
        u.dig("identifiers", 0, "id") == "NISTu1"
      end
      expect(meter).not_to be_nil
      expect(meter["short"]).to eq("meter")
    end

    it "prefixes.yaml contains the kilo prefix" do
      file_path = File.join(data_dir, "prefixes.yaml")
      hash = YAML.safe_load_file(file_path)
      kilo = hash["prefixes"].find do |p|
        p.dig("identifiers", 0, "id") == "NISTp10_3"
      end
      expect(kilo).not_to be_nil
      expect(kilo["short"]).to eq("kilo")
    end

    it "dimensions.yaml contains the length dimension" do
      file_path = File.join(data_dir, "dimensions.yaml")
      hash = YAML.safe_load_file(file_path)
      length = hash["dimensions"].find do |d|
        d.dig("identifiers", 0, "id") == "NISTd1"
      end
      expect(length).not_to be_nil
    end

    it "quantities.yaml contains the length quantity" do
      file_path = File.join(data_dir, "quantities.yaml")
      hash = YAML.safe_load_file(file_path)
      length = hash["quantities"].find do |q|
        q.dig("identifiers", 0, "id") == "NISTq1"
      end
      expect(length).not_to be_nil
    end

    it "unit_systems.yaml contains the SI unit system" do
      file_path = File.join(data_dir, "unit_systems.yaml")
      hash = YAML.safe_load_file(file_path)
      si = hash["unit_systems"].find do |s|
        s.dig("identifiers", 0, "id") == "SI_base"
      end
      expect(si).not_to be_nil
    end

    it "scales.yaml is a valid YAML file with a top-level key" do
      file_path = File.join(data_dir, "scales.yaml")
      hash = YAML.safe_load_file(file_path)
      expect(hash).to be_a(Hash)
      expect(hash.keys).not_to be_empty
    end
  end
end
