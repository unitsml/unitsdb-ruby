# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unitsdb::Configuration do
  let(:database_path) { File.join(__dir__, "../../data") }

  around do |example|
    original_models = described_class.registered_models.dup
    original_registers = described_class.explicit_registers.dup

    Lutaml::Model::GlobalContext.reset!
    Unitsdb.instance_variable_set(:@databases, nil)
    example.run
  ensure
    %i[custom_unitsdb custom_unitsdb_with_register].each do |id|
      Lutaml::Model::GlobalRegister.unregister(id)
    rescue StandardError
      nil
    end
    described_class.instance_variable_set(:@registered_models, original_models)
    described_class.instance_variable_set(:@explicit_registers, original_registers)
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
end
