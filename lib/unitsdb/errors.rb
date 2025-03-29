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
  end
end
