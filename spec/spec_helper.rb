# frozen_string_literal: true

require_relative "../lib/unitsdb"
require "stringio"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

require "canon"

# Define a helper method for capturing standard output/error
def capture_output
  original_stdout = $stdout
  original_stderr = $stderr
  $stdout = StringIO.new
  $stderr = StringIO.new
  yield
  { output: $stdout.string, error: $stderr.string }
ensure
  $stdout = original_stdout
  $stderr = original_stderr
end

require "lutaml/model"
# Configure LutaML adapters
Lutaml::Model::Config.configure do |config|
  config.xml_adapter_type = :nokogiri
  config.yaml_adapter_type = :standard_yaml
end
