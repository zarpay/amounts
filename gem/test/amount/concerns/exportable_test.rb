# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/locale_test_setup"

class AmountExportableTest < Minitest::Test
  include LocaleTestSetup

  def test_manifest_exports_the_global_registry
    assert_equal Amount::Manifest.new(Amount.registry).to_h, Amount.manifest
  end

  def test_manifest_resolves_the_given_locales
    assert_equal Amount::Manifest.new(Amount.registry, locales: [:de]).to_h, Amount.manifest(locales: [:de])
  end

  def test_manifest_follows_a_swapped_registry
    exported = Amount.with_registry(Amount::Registry.new) do
      Amount.register :TEST, decimals: 2
      Amount.manifest
    end

    assert_equal %w[TEST], exported["types"].keys
  end
end
