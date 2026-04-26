# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"
require_relative "../lib/amounts"
require_relative "../lib/generators/amount/active_record/registry_generator"
require "rails/generators"

class AmountRegistryGeneratorTest < Minitest::Test
  def setup
    @destination_root = Dir.mktmpdir("amounts-generator")
  end

  def teardown
    FileUtils.remove_entry(@destination_root)
  end

  def test_generates_fiat_initializer
    invoke_generator("fiat")

    content = File.read(output_file)

    assert_includes content, 'rails generate amounts:registry fiat'
    assert_includes content, "# Registry overview:"
    assert_includes content, "# Major Fiat Currencies:"
    assert_includes content, "# USD: United States dollar."
    assert_includes content, "# Fact: Uses 2 decimal places for cents."
    assert_includes content, "# Preset default: Uses \"$\" as the default display symbol in an English-oriented UI."
    assert_includes content, "Amount.register :USD"
    assert_includes content, "Amount.register :JPY"
    refute_includes content, "Amount.register :BTC"
  end

  def test_generates_all_initializer_without_duplicate_symbols
    invoke_generator("all")

    content = File.read(output_file)

    assert_equal 1, content.scan(/^\s*Amount\.register :USD,/).size
    assert_equal 1, content.scan(/^\s*Amount\.register :USDC,/).size
    assert_includes content, "Amount.register :GOLD"
    assert_includes content, "Amount.register :BTC"
  end

  def test_generates_crypto_initializer_without_stale_polygon_entry
    invoke_generator("crypto")

    content = File.read(output_file)

    assert_includes content, "# BTC: Bitcoin."
    assert_includes content, "# Source: Ethereum denomination docs: https://ethereum.org/en/developers/docs/intro-to-ether/"
    assert_includes content, "Amount.register :USDT"
    refute_includes content, "Amount.register :MATIC"
    refute_includes content, "Amount.register :POL"
  end

  def test_static_preset_files_exist
    assert File.exist?(preset_file("fiat"))
    assert File.exist?(preset_file("metals"))
    assert File.exist?(preset_file("crypto"))
    assert File.exist?(preset_file("all"))
  end

  def test_all_static_preset_file_includes_all_major_sections
    content = File.read(preset_file("all"))

    assert_includes content, "# Major Fiat Currencies:"
    assert_includes content, "# Precious And Industrial Metals:"
    assert_includes content, "# Large-Cap Crypto Assets:"
    assert_includes content, "Amount.register :USD"
    assert_includes content, "Amount.register :GOLD"
    assert_includes content, "Amount.register :BTC"
  end

  def test_rejects_unknown_preset
    _stdout, stderr = capture_io do
      invoke_generator("unknown")
    end
    assert_includes stderr, "unknown preset"
  end

  private

  def invoke_generator(preset)
    Amount::ActiveRecord::RegistryGenerator.start(
      [preset],
      destination_root: @destination_root,
      shell: Thor::Shell::Basic.new
    )
  end

  def output_file
    File.join(@destination_root, "config/initializers/amounts.rb")
  end

  def preset_file(name)
    File.join(
      File.dirname(__FILE__),
      "..",
      "lib/generators/amount/active_record/templates/presets/#{name}.fragment"
    )
  end
end
