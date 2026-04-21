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
    around do |example|
      described_class.instance_variable_set(:@databases, nil)
      Lutaml::Model::GlobalContext.reset!
      example.run
    ensure
      described_class.instance_variable_set(:@databases, nil)
      Lutaml::Model::GlobalContext.reset!
    end

    it "boots successfully on first access and caches the bundled database" do
      db = described_class.database

      expect(db).to be_a(Unitsdb::Database)
      expect(db.schema_version).to eq("2.0.0")
      expect(described_class.database).to equal(db)
    end

    it "loads known entities across each bundled collection" do
      db = described_class.database

      aggregate_failures do
        expect(db.get_by_id(id: "NISTu1")).to be_a(Unitsdb::Unit)
        expect(db.get_by_id(id: "NISTp10_3")).to be_a(Unitsdb::Prefix)
        expect(db.get_by_id(id: "NISTd1")).to be_a(Unitsdb::Dimension)
        expect(db.get_by_id(id: "NISTq1")).to be_a(Unitsdb::Quantity)
        expect(db.get_by_id(id: "SI_base")).to be_a(Unitsdb::UnitSystem)
      end
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
