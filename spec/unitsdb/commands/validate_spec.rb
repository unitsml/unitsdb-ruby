# frozen_string_literal: true

require "spec_helper"
require "unitsdb/commands/validate"
require "stringio"

RSpec.describe Unitsdb::Commands::ValidateCommand do
  let(:validate_command) { described_class.new }

  # No global output capture - each test will capture output explicitly
end
