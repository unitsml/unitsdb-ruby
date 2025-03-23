# frozen_string_literal: true

module Unitsdb
  # Base error class for all UnitsDB errors
  module Errors
    class BaseError < StandardError; end

    # Database-related errors
    class DatabaseError < BaseError; end
    class DatabaseNotFoundError < DatabaseError; end
    class DatabaseLoadError < DatabaseError; end
    class DatabaseFileNotFoundError < DatabaseError; end
    class DatabaseFileInvalidError < DatabaseError; end

    # Version-related errors
    class VersionMismatchError < BaseError; end

    # Validation errors
    class ValidationError < BaseError; end
    class DuplicateIdentifierError < ValidationError; end
    class InvalidReferenceError < ValidationError; end
  end
end
