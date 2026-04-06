# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Unitsdb context support" do
  let(:database_path) { File.join(__dir__, "../../data") }

  around do |example|
    original_models = Unitsdb::Configuration.registered_models.dup

    Lutaml::Model::GlobalContext.reset!
    Unitsdb.instance_variable_set(:@databases, nil)
    example.run
  ensure
    Unitsdb::Configuration.instance_variable_set(:@registered_models, original_models)
    Lutaml::Model::GlobalContext.reset!
    Unitsdb.instance_variable_set(:@databases, nil)
  end

  it "applies substitutions in a custom context during database load" do
    stub_const("CustomContextUnit", Class.new(Unitsdb::Unit))

    Unitsdb::Configuration.register_model(Unitsdb::Unit, id: :unit)
    Unitsdb::Configuration.register_model(CustomContextUnit, id: :custom_unit)

    Unitsdb::Configuration.populate_context(
      id: :custom_unitsdb,
      fallback_to: [Unitsdb::Configuration.context_id],
      substitutions: [
        { from_type: :unit, to_type: :custom_unit },
      ],
    )
    Unitsdb::Configuration.populate_register(
      id: :custom_unitsdb,
      fallback: [Unitsdb::Configuration.context_id],
      substitutions: [
        { from_type: :unit, to_type: :custom_unit },
      ],
    )

    db = Unitsdb::Database.from_db(database_path, context: :custom_unitsdb)

    expect(db.units.first).to be_a(CustomContextUnit)
    expect(db.get_by_id(id: "NISTu1")).to be_a(CustomContextUnit)
  end
end
