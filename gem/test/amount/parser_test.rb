# frozen_string_literal: true

require_relative "../test_helper"

class AmountParserTest < Minitest::Test
  def setup
    AmountTestSupport.register_default_types!
  end

  def teardown
    Amount.registry.clear!
  end

  def test_parse_accepts_explicit_v1_prefix
    assert_equal Amount.new("1.5", :USDC), Amount.parse("v1:USDC|1.5")
  end

  def test_parse_rejects_unknown_version_prefix
    assert_raises(Amount::InvalidInput) { Amount.parse("v2:USDC|1.5") }
  end

  def test_parse_rejects_missing_value
    assert_raises(Amount::InvalidInput) { Amount.parse("USDC|") }
  end

  def test_parse_rejects_missing_symbol
    assert_raises(Amount::InvalidInput) { Amount.parse("|1.5") }
  end
end
