# frozen_string_literal: true

require "spec_helper"
require "unitsdb/cli"

RSpec.describe Unitsdb::Cli do
  let(:database_path) { "data" }

  describe "subcommand dispatch" do
    it "registers validate as a subcommand" do
      expect(described_class.subcommand_classes["validate"])
        .to eq(Unitsdb::Commands::ValidateCommand)
    end

    it "registers _modify as a subcommand" do
      expect(described_class.subcommand_classes["_modify"])
        .to eq(Unitsdb::Commands::ModifyCommand)
    end

    it "registers ucum as a subcommand" do
      expect(described_class.subcommand_classes["ucum"])
        .to eq(Unitsdb::Commands::UcumCommand)
    end

    it "registers qudt as a subcommand" do
      expect(described_class.subcommand_classes["qudt"])
        .to eq(Unitsdb::Commands::QudtCommand)
    end
  end

  describe "search subcommand" do
    it "prints matches for a known term" do
      output = capture_output do
        described_class.start(%W[search meter -d #{database_path}])
      end

      expect(output[:output]).to include("Found")
      expect(output[:output]).to include("Unit")
    end

    it "prints a no-results message for an unknown term" do
      output = capture_output do
        described_class.start(%W[search zzz-no-such-term -d #{database_path}])
      end

      expect(output[:output]).to include("No results found")
    end
  end

  describe "get subcommand" do
    it "prints entity details for a known id" do
      output = capture_output do
        described_class.start(%W[get NISTu1 -d #{database_path}])
      end

      expect(output[:output]).to include("Entity details:")
      expect(output[:output]).to include("Type: Unit")
    end

    it "prints a not-found message for an unknown id" do
      output = capture_output do
        described_class.start(%W[get zzz-no-such-id -d #{database_path}])
      end

      expect(output[:output]).to include("No entity found with ID:")
    end

    it "supports --format json" do
      output = capture_output do
        described_class.start(%W[get NISTu1 -d #{database_path} --format json])
      end

      expect(output[:output]).to include('"short":')
    end
  end

  describe "validate subcommand" do
    it "runs `validate references` and prints a summary" do
      output = capture_output do
        described_class.start(%W[validate references -d #{database_path}])
      end

      expect(output[:output]).to match(/references are valid|invalid references/i)
    end

    it "runs `validate identifiers`" do
      output = capture_output do
        described_class.start(%W[validate identifiers -d #{database_path}])
      end

      expect(output[:output]).to match(/duplicate 'short'|duplicate 'id'|No duplicate/i)
    end
  end

  describe "--trace" do
    it "re-raises the underlying error when --trace is set" do
      expect do
        described_class.start(%w[get NISTu1 -d /does/not/exist --trace])
      end.to raise_error(Unitsdb::Errors::DatabaseError)
    end
  end
end
