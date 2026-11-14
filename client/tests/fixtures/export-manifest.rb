# frozen_string_literal: true

# Writes manifest.json from registry.rb through the gem. Run from gem/:
#
#   bundle exec ruby -Ilib ../client/tests/fixtures/export-manifest.rb

require "json"
require_relative "registry"

path = File.expand_path("manifest.json", __dir__)
File.write(path, "#{JSON.pretty_generate(Amount.manifest(locales: %i[en de fr]))}\n")
