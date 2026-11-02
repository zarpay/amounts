# frozen_string_literal: true

require_relative "../../../test_helper"
require "tmpdir"
require "fileutils"
require_relative "../../../../lib/amounts"
require_relative "../../../../lib/generators/amount/active_record/registry_generator"
require "rails/generators"

class AmountActiveRecordRegistryGeneratorTest < Minitest::Test
  PRESETS_DIR = File.expand_path("../../../../lib/generators/amount/active_record/templates/presets", __dir__)

  def setup
    @destination_root = Dir.mktmpdir("amounts-generator")
  end

  def teardown
    FileUtils.remove_entry(@destination_root)
  end

  {
    "rails_generate_command" => "rails generate amounts:registry fiat",
    "registry_overview" => "# Registry overview:",
    "fiat_section" => "# Major Fiat Currencies:",
    "usd_description" => "# USD: United States dollar.",
    "usd_fact" => "# Fact: Uses 2 decimal places for cents.",
    "usd_preset_default" => "# Preset default: Uses \"$\" as the default display symbol in an English-oriented UI.",
    "usd_registration" => "Amount.register :USD",
    "jpy_registration" => "Amount.register :JPY"
  }.each do |name, text|
    define_method("test_fiat_initializer_includes_#{name}") do
      assert_includes generated("fiat"), text
    end
  end

  def test_fiat_initializer_excludes_btc_registration
    refute_includes generated("fiat"), "Amount.register :BTC"
  end

  %w[USD USDC].each do |symbol|
    define_method("test_all_initializer_registers_#{symbol}_once") do
      assert_equal 1, generated("all").scan(/^\s*Amount\.register :#{symbol},/).size
    end
  end

  %w[GOLD BTC].each do |symbol|
    define_method("test_all_initializer_registers_#{symbol}") do
      assert_includes generated("all"), "Amount.register :#{symbol}"
    end
  end

  {
    "btc_description" => "# BTC: Bitcoin.",
    "ethereum_source" => "# Source: Ethereum denomination docs: https://ethereum.org/en/developers/docs/intro-to-ether/",
    "usdt_registration" => "Amount.register :USDT"
  }.each do |name, text|
    define_method("test_crypto_initializer_includes_#{name}") do
      assert_includes generated("crypto"), text
    end
  end

  %w[MATIC POL].each do |symbol|
    define_method("test_crypto_initializer_excludes_stale_#{symbol}_registration") do
      refute_includes generated("crypto"), "Amount.register :#{symbol}"
    end
  end

  %w[fiat metals crypto all].each do |preset|
    define_method("test_static_#{preset}_preset_file_exists") do
      assert File.exist?(preset_file(preset))
    end
  end

  {
    "fiat_section" => "# Major Fiat Currencies:",
    "metals_section" => "# Precious And Industrial Metals:",
    "crypto_section" => "# Large-Cap Crypto Assets:",
    "usd_registration" => "Amount.register :USD",
    "gold_registration" => "Amount.register :GOLD",
    "btc_registration" => "Amount.register :BTC"
  }.each do |name, text|
    define_method("test_all_static_preset_file_includes_#{name}") do
      assert_includes File.read(preset_file("all")), text
    end
  end

  def test_rejects_unknown_preset
    _stdout, stderr = capture_io do
      invoke_generator("unknown")
    end
    assert_includes stderr, "unknown preset"
  end

  private

  # The initializer generated for the preset, generated once per test.
  def generated(preset)
    @generated ||= {}
    @generated[preset] ||= begin
      invoke_generator(preset)
      File.read(File.join(@destination_root, "config/initializers/amounts.rb"))
    end
  end

  def invoke_generator(preset)
    Amount::ActiveRecord::RegistryGenerator.start(
      [preset],
      destination_root: @destination_root,
      shell: Thor::Shell::Basic.new
    )
  end

  def preset_file(name)
    File.join(PRESETS_DIR, "#{name}.fragment")
  end
end
