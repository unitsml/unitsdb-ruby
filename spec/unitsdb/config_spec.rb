# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unitsdb::Config do
  let(:database_path) { File.join(__dir__, "../../data") }

  around do |example|
    original_models = Unitsdb::Config.registered_models.dup
    original_registers = Unitsdb::Config.explicit_registers.dup
    original_legacy_models = Unitsdb::Config.models.dup

    Lutaml::Model::GlobalContext.reset!
    Unitsdb.instance_variable_set(:@databases, nil)
    example.run
  ensure
    %i[custom_unitsdb custom_unitsdb_with_register].each do |id|
      Lutaml::Model::GlobalRegister.unregister(id)
    rescue StandardError
      nil
    end
    Unitsdb::Config.instance_variable_set(:@registered_models, original_models)
    Unitsdb::Config.instance_variable_set(:@explicit_registers, original_registers)
    Unitsdb::Config.instance_variable_set(:@models, original_legacy_models)
    Lutaml::Model::GlobalContext.reset!
    Unitsdb.instance_variable_set(:@databases, nil)
  end

  it "builds a custom context without implicitly using it as a register" do
    stub_const("CustomContextUnit", Class.new(Unitsdb::Unit))

    described_class.register_model(Unitsdb::Unit, id: :unit)
    described_class.register_model(CustomContextUnit, id: :custom_unit)

    described_class.populate_context(
      id: :custom_unitsdb,
      fallback_to: [described_class.context_id],
      substitutions: [
        { from_type: :unit, to_type: :custom_unit },
      ],
    )

    db = Unitsdb::Database.from_db(database_path, context: :custom_unitsdb)
    context = described_class.context(:custom_unitsdb)

    expect(context).not_to be_nil
    expect(context.substitutions.length).to eq(1)
    expect(described_class.register(:custom_unitsdb)).to be_nil
    expect(db.units.first).to be_a(Unitsdb::Unit)
    expect(db.units.first).not_to be_a(CustomContextUnit)
    expect(db.get_by_id(id: "NISTu1")).to be_a(Unitsdb::Unit)
  end

  it "uses a custom context as a register after explicit register population" do
    stub_const("CustomContextUnitWithRegister", Class.new(Unitsdb::Unit))

    described_class.register_model(Unitsdb::Unit, id: :unit)
    described_class.register_model(CustomContextUnitWithRegister,
                                   id: :custom_unit_with_register)

    described_class.populate_context(
      id: :custom_unitsdb_with_register,
      fallback_to: [described_class.context_id],
      substitutions: [
        { from_type: :unit, to_type: :custom_unit_with_register },
      ],
    )

    described_class.populate_register(
      id: :custom_unitsdb_with_register,
      fallback_to: [described_class.context_id],
    )

    db = Unitsdb::Database.from_db(database_path,
                                   context: :custom_unitsdb_with_register)

    expect(described_class.register(:custom_unitsdb_with_register)).not_to be_nil
    expect(db.units.first).to be_a(CustomContextUnitWithRegister)
  end

  describe "compatibility" do
    it "keeps Unitsdb::Configuration as an alias of Config" do
      expect(Unitsdb::Configuration).to be(Unitsdb::Config)
      expect(Unitsdb::Configuration.respond_to?(:populate_register)).to be(true)
    end

    it "uses eagerly loaded core models without a bootstrap manifest" do
      expect(Unitsdb::Config.const_defined?(:CORE_MODEL_CONSTANTS, false)).to be(false)
      expect(Unitsdb.respond_to?(:load_core_models!)).to be(false)
      expect(described_class.send(:build_registry)).to be_a(Lutaml::Model::TypeRegistry)
      expect(described_class.registered_models[:database]).to be(Unitsdb::Database)
      expect(described_class.context).not_to be_nil
      expect(described_class.resolve_type(:database)).to be(Unitsdb::Database)
    end

    it "keeps the legacy model registration interface available on Config" do
      stub_const("LegacyConfiguredUnit", Class.new(Unitsdb::Unit))

      described_class.models = { unit: LegacyConfiguredUnit }

      expect(described_class.model_for(:unit)).to be(LegacyConfiguredUnit)
      expect(Unitsdb::Config.registered_models[:unit]).to be(LegacyConfiguredUnit)
    end
  end

  describe ".database integration" do
    it "does not auto-create third-party contexts" do
      expect(described_class).not_to receive(:context).with(:unitsml_ruby)
      allow(described_class).to receive(:resolve_type)
        .with(:database, context: :unitsml_ruby)
        .and_return(Unitsdb::Database)
      allow(Unitsdb::Database).to receive(:from_db).and_return(:foreign_context_db)

      expect(Unitsdb.database(context: :unitsml_ruby)).to eq(:foreign_context_db)
    end
  end
end
