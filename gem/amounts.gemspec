# frozen_string_literal: true

require_relative "lib/amount/version"

Gem::Specification.new do |spec|
  spec.name = "amounts"
  spec.version = Amount::VERSION
  spec.authors = ["Seb Scholl"]
  spec.email = ["opensource@example.com"]

  spec.summary = "Precise registered quantities for money, tokens, commodities, and other fungible things."
  spec.description = <<~TEXT
    Amounts provides a precise Amount value object with atomic integer storage,
    safe registered-type arithmetic, explicit conversion rates, display helpers,
    and an optional ActiveRecord integration layer.
  TEXT
  spec.homepage = "https://github.com/zarpay/amounts"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "bug_tracker_uri"   => "https://github.com/zarpay/amounts/issues",
    "changelog_uri"     => "https://github.com/zarpay/amounts/blob/main/gem/CHANGELOG.md",
    "documentation_uri" => "https://github.com/zarpay/amounts/tree/main/gem#readme",
    "source_code_uri"   => "https://github.com/zarpay/amounts/tree/main/gem"
  }

  spec.files = Dir.glob("{bin,lib,test,.github}/**/*", File::FNM_DOTMATCH).reject do |path|
    File.directory?(path) || path.include?("/.") || path.start_with?(".github/")
  end + %w[
    CHANGELOG.md
    Gemfile
    LICENSE.txt
    README.md
    Rakefile
    .rubocop.yml
  ]
  spec.bindir = "bin"
  spec.executables = ["console", "setup"]
  spec.require_paths = ["lib"]

  spec.add_dependency "bigdecimal"
end
