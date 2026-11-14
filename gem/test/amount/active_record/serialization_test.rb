# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/active_record_test_support"

class AmountActiveRecordSerializationTest < Minitest::Test
  include ActiveRecordTestSetup

  def setup
    super
    @holding = Holding.create!(amount: "USDC|10.06", fee: "SOL|1.123456789")
  end

  def test_serializes_amounts_in_place_of_their_columns
    assert_equal %w[id amount fee reserve bonus_atomic parent_id], @holding.as_json.keys
  end

  def test_serializes_multi_symbol_amount_as_exact_compact_string
    assert_equal "USDC|10.060000", @holding.as_json["amount"]
  end

  def test_serializes_fixed_symbol_amount_as_exact_compact_string
    assert_equal "SOL|1.123456789", @holding.as_json["fee"]
  end

  def test_serializes_nil_amount_as_nil
    assert_nil Holding.create!.as_json["fee"]
  end

  def test_serializable_hash_holds_the_amount
    assert_equal Amount.new("1.123456789", :SOL), @holding.serializable_hash["fee"]
  end

  def test_only_takes_an_amount_name
    assert_equal({ "fee" => "SOL|1.123456789" }, @holding.as_json(only: :fee))
  end

  def test_only_takes_amount_names_with_columns
    assert_equal({ "id" => @holding.id, "amount" => "USDC|10.060000" }, @holding.as_json(only: %i[id amount]))
  end

  def test_except_takes_an_amount_name
    assert_equal %w[id fee bonus_atomic parent_id], @holding.as_json(except: %i[amount reserve]).keys
  end

  def test_to_json_writes_amounts
    assert_equal '{"fee":"SOL|1.123456789"}', @holding.to_json(only: :fee)
  end

  def test_keeps_columns_of_partly_selected_amount
    assert_equal %w[id amount_atomic], Holding.select(:id, :amount_atomic).first.as_json.keys
  end

  def test_serializes_amounts_of_included_association
    child = ChildHolding.create!(parent: @holding)

    assert_equal({ "fee" => "SOL|1.123456789" }, child.as_json(only: :id, include: { parent: { only: :fee } })["parent"])
  end

  def test_serializes_inherited_amount
    assert_equal "SOL|1.123456789", SubHolding.find(@holding.id).as_json["fee"]
  end

  def test_serializes_amount_a_subclass_adds
    assert_equal "SOL|2.000000000", BonusHolding.create!(bonus: "SOL|2").as_json["bonus"]
  end

  def test_included_only_into_models_with_amounts
    refute_includes ::ActiveRecord::Base.ancestors, Amount::ActiveRecord::Serialization
  end

  def test_included_once_per_model
    assert_equal 1, BonusHolding.ancestors.count(Amount::ActiveRecord::Serialization)
  end
end
