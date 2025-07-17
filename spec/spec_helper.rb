# frozen_string_literal: true

require "unitsdb"
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

require "yaml"
require "diffy"

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

RSpec::Matchers.define :be_yaml_equivalent_to do |expected|
  match do |actual|
    @actual_sorted = sort_yaml_keys(YAML.safe_load(actual)).to_yaml
    @expected_sorted = sort_yaml_keys(YAML.safe_load(expected)).to_yaml
    @actual_sorted == @expected_sorted
  end

  def sort_yaml_keys(obj)
    case obj
    when Hash
      obj.transform_values { |v| sort_yaml_keys(v) }
        .sort.to_h
    when Array
      obj.map { |item| sort_yaml_keys(item) }
    else
      obj
    end
  end

  failure_message do |_actual|
    diff = Diffy::Diff.new(@expected_sorted, @actual_sorted,
                           include_diff_info: false,
                           include_plus_and_minus_in_html: true,
                           diff_options: "-u")

    "expected YAML to be equivalent\n\n" \
    "Diff:\n" +
      diff.to_s(:color)
  end
end

# Configure LutaML adapters
Lutaml::Model::Config.configure do |config|
  config.xml_adapter_type = :nokogiri
  config.yaml_adapter_type = :standard_yaml
end
