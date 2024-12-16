# frozen_string_literal: true

require_relative "lib/unitsdb/version"

Gem::Specification.new do |spec|
  spec.name = "unitsdb"
  spec.version = Unitsdb::VERSION
  spec.authors = ["Ribose Inc."]
  spec.email = ["open.source@ribose.com"]

  spec.summary = "Ruby library for UnitsDB"
  spec.description = "Library to generate Ruby instances of UnitsDB content"
  spec.homepage = "https://github.com/unitsml/unitsdb-ruby"
  spec.license = "BSD-2-Clause"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.0.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/unitsml/unitsdb-ruby/releases"
  spec.metadata["rubygems_mfa_required"] = "true"


  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/})
    end
  end
  spec.bindir = "exe"
  spec.require_paths = ["lib"]

  spec.add_dependency "lutaml", "~> 0.3"
end
