# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unitsdb::Configuration do
  let(:database_path) { File.join(__dir__, "../../data") }

  around do |example|
    original_models = described_class.registered_models.dup

    Lutaml::Model::GlobalContext.reset!
    Unitsdb.instance_variable_set(:@databases, nil)
    example.run
  ensure
    described_class.instance_variable_set(:@registered_models, original_models)
    Lutaml::Model::GlobalContext.reset!
    Unitsdb.instance_variable_set(:@databases, nil)
  end

  it "builds a custom context and loads database data using it" do
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
    expect(db.units.first).to be_a(Unitsdb::Unit)
    expect(db.get_by_id(id: "NISTu1")).to be_a(Unitsdb::Unit)
  end
end
