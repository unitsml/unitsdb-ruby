# frozen_string_literal: true

require_relative "lib/unitsdb/version"

Gem::Specification.new do |spec|
  spec.name = "unitsdb"
  spec.version = Unitsdb::VERSION
  spec.authors = ["Ribose Inc."]
  spec.email = ["open.source@ribose.com"]

  spec.summary = "Ruby library for UnitsDB"
  spec.description = "Library to handle UnitsDB content."
  spec.homepage = "https://github.com/unitsml/unitsdb-ruby"

  spec.license = "BSD-2-Clause"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.0.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/unitsml/unitsdb-ruby/releases"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.test_files = `git ls-files -- {spec}/*`.split("\n")
  spec.require_paths = ["lib"]

  spec.add_dependency "lutaml-model", "~>0.7"
  spec.add_dependency "rdf", "~> 3.1"
  spec.add_dependency "rdf-turtle", "~> 3.1"
  spec.add_dependency "rubyzip", "~> 2.3"
  spec.add_dependency "terminal-table"
  spec.add_dependency "thor", "~> 1.0"
end
