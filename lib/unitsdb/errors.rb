# frozen_string_literal: true

module Unitsdb
  module Errors
    class DatabaseError < StandardError; end
    class DatabaseNotFoundError < DatabaseError; end
    class DatabaseFileNotFoundError < DatabaseError; end
    class DatabaseFileInvalidError < DatabaseError; end
    class DatabaseLoadError < DatabaseError; end
    class VersionMismatchError < DatabaseError; end
    class UnsupportedVersionError < DatabaseError; end

    # CLI-specific errors
    class CLIRuntimeError < StandardError; end
    class InvalidParameterError < CLIRuntimeError; end
    class FileNotFoundError < CLIRuntimeError; end
    class ValidationError < CLIRuntimeError; end
    class InvalidFormatError < CLIRuntimeError; end
  end
end
