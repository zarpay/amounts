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
  spec.required_ruby_version = ">= 3.0"

  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/zarpay/amounts/issues",
    "changelog_uri" => "https://github.com/zarpay/amounts/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://github.com/zarpay/amounts#readme",
    "source_code_uri" => "https://github.com/zarpay/amounts"
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

  spec.add_runtime_dependency "bigdecimal"

  spec.add_development_dependency "activerecord", ">= 7.1", "< 8.0"
  spec.add_development_dependency "irb", ">= 1.13"
  spec.add_development_dependency "minitest", ">= 5.0"
  spec.add_development_dependency "rake", ">= 13.0"
  spec.add_development_dependency "rspec", ">= 3.13"
  spec.add_development_dependency "rubocop", ">= 1.70"
  spec.add_development_dependency "sqlite3", ">= 2.0"
  spec.add_development_dependency "yard", ">= 0.9"
end
