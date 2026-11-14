# frozen_string_literal: true

require_relative "../test_helper"

begin
  require "pg"
rescue LoadError
  # Handled in setup.
end

ENV["RAILS_ENV"] = "test"

require_relative "../dummy/config/environment"
require "active_record/tasks/database_tasks"

class PostgreSQLIntegrationTest < Minitest::Test
  DUMMY_ROOT = File.expand_path("../dummy", __dir__)

  def setup
    skip "pg gem is not installed" unless defined?(PG)
    skip "set AMOUNTS_POSTGRES_URL to run PostgreSQL integration tests" unless ENV["AMOUNTS_POSTGRES_URL"]

    AmountTestSupport.register_active_record_types!
    configure_database_tasks
    recreate_schema!
    # With a URL set, an unreachable database is an error, not a skip, so a
    # broken CI service can't pass silently.
    Holding.delete_all
  end

  def teardown
    Amount.registry.clear!
  end

  def test_postgresql_round_trips_large_atomic_values_exactly
    huge_atomic = 10**30
    holding = Holding.create!(amount: Amount.new(huge_atomic, :SOL, from: :atomic))

    assert_equal huge_atomic, holding.reload.amount.atomic
  end

  def test_postgresql_uses_default_numeric_precision_for_amount_columns
    assert_equal 78, Holding.columns_hash.fetch("amount_atomic").precision
  end

  # Rails reports `scale` as nil for any zero-scale decimal, so check the
  # column type PostgreSQL actually created.
  def test_postgresql_uses_zero_scale_for_amount_columns
    assert_equal "numeric(78,0)", Holding.columns_hash.fetch("amount_atomic").sql_type
  end

  def test_postgresql_uses_given_numeric_precision_for_amount_columns
    assert_equal 40, Holding.columns_hash.fetch("reserve_atomic").precision
  end

  def test_postgresql_uses_zero_scale_for_amount_columns_with_given_precision
    assert_equal "numeric(40,0)", Holding.columns_hash.fetch("reserve_atomic").sql_type
  end

  def test_postgresql_where_query_works_with_amount_columns
    usdc = create_usdc_and_usd_holdings

    assert_equal [usdc.id], Holding.where_amount("USDC|1.50").pluck(:id)
  end

  def test_postgresql_group_query_works_with_amount_columns
    create_usdc_and_usd_holdings

    assert_equal({ "USDC" => 1_500_000, "USD" => 300 }, Holding.group(:amount_symbol).sum(:amount_atomic))
  end

  def test_postgresql_sum_amount_is_exact_past_64_bits
    holdings_with_atomic_amounts(10**30, (10**30) + 1)

    assert_equal (2 * (10**30)) + 1, Holding.sum_amount(:amount).atomic
  end

  def test_postgresql_average_amount_is_exact_past_64_bits
    holdings_with_atomic_amounts(10**30, (10**30) + 3)

    assert_equal (10**30) + 1, Holding.average_amount(:amount).atomic
  end

  def test_postgresql_sum_amount_of_fixed_symbol
    Holding.create!(fee: "SOL|0.1")
    Holding.create!(fee: "SOL|0.2")

    assert_equal Amount.new("0.3", :SOL), Holding.sum_amount(:fee)
  end

  def test_postgresql_sum_amount_grouped_by_symbol_column
    create_usdc_and_usd_holdings

    assert_equal({ "USDC" => Amount.new("1.5", :USDC), "USD" => Amount.new("3", :USD) },
                 Holding.group(:amount_symbol).sum_amount(:amount))
  end

  def test_postgresql_sum_amount_of_several_attributes_is_exact_past_64_bits
    holdings_with_atomic_amounts(10**30, (10**30) + 1)

    assert_equal({ amount: Amount.new((2 * (10**30)) + 1, :SOL, from: :atomic), fee: Amount.new(0, :SOL) },
                 Holding.sum_amount(:amount, :fee))
  end

  def test_postgresql_average_amount_of_several_attributes_is_exact_past_64_bits
    holdings_with_atomic_amounts(10**30, (10**30) + 3)

    assert_equal Amount.new((10**30) + 1, :SOL, from: :atomic),
                 Holding.average_amount(:amount, :reserve).fetch(:amount)
  end

  def test_postgresql_sum_amount_of_several_attributes_grouped
    create_usdc_and_usd_holdings

    assert_equal({ amount: Amount.new("1.5", :USDC), reserve: Amount.new("1.25", :USDC) },
                 Holding.group(:amount_symbol).sum_amount(:amount, :reserve).fetch("USDC"))
  end

  private

  def holdings_with_atomic_amounts(*atomics)
    atomics.each { |atomic| Holding.create!(amount: Amount.new(atomic, :SOL, from: :atomic)) }
  end

  # The USDC holding; a USD holding is created alongside.
  def create_usdc_and_usd_holdings
    usdc = Holding.create!(amount: "USDC|1.50")
    Holding.create!(amount: "USD|3.00")
    usdc
  end

  def configure_database_tasks
    ActiveRecord::Tasks::DatabaseTasks.database_configuration = Rails.application.config.database_configuration
    ActiveRecord::Tasks::DatabaseTasks.db_dir = File.join(DUMMY_ROOT, "db")
    ActiveRecord::Tasks::DatabaseTasks.env = "test"
    ActiveRecord::Tasks::DatabaseTasks.root = DUMMY_ROOT
  end

  def recreate_schema!
    ActiveRecord::Base.establish_connection(:test)
    ActiveRecord::Migration.verbose = false
    load File.join(DUMMY_ROOT, "db/schema.rb")
    Holding.reset_column_information
  end
end
