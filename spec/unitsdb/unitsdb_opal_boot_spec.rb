# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unitsdb do
  subject(:boot_file) do
    File.read(File.expand_path("../../lib/unitsdb/opal.rb", __dir__))
  end

  let(:required_paths) do
    boot_file.scan(/^require "unitsdb\/([^"]+)"/).flatten
  end

  let(:available_paths) do
    Dir[File.expand_path("../../lib/unitsdb/*.rb", __dir__)]
      .map { |f| File.basename(f, ".rb") }
  end

  let(:skipped) do
    # "opal" is this file itself; "cli" and "commands" are native-only.
    # "version" is loaded by the gemspec (not by lib/unitsdb.rb), so under
    # Opal the consumer is responsible for requiring it via the gem runtime.
    %w[opal cli commands version]
  end

  describe "opal boot file at lib/unitsdb/opal.rb" do
    it "eager-requires every unitsdb entry point that lib/unitsdb.rb exposes" do
      expected = available_paths - skipped
      missing = expected - required_paths
      expect(missing).to be_empty,
                         "boot file is missing eager requires for: #{missing.inspect}"
    end

    it "does not eager-require Opal-gated entry points" do
      expect(required_paths).not_to include("cli", "commands")
    end

    it "only references files that exist on disk" do
      missing = required_paths - available_paths
      expect(missing).to be_empty,
                         "boot file references non-existent files: #{missing.inspect}"
    end

    it "compiles under Opal when external deps are stubbed" do
      require "opal"
      require "opal/builder"

      builder = Opal::Builder.new
      builder.append_paths(File.expand_path("../../lib", __dir__))
      # Stub native-only deps that have no Opal-compatible build at this layer.
      # The gem's Opal consumer (plurimath-js) provides these.
      builder.stubs += %w[lutaml/model]

      expect { builder.build("unitsdb/opal") }.not_to raise_error
    end
  end
end
