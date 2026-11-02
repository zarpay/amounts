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
    Holding.delete_all
  rescue PG::Error, ActiveRecord::ConnectionNotEstablished => error
    skip "PostgreSQL is unavailable: #{error.message}"
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

  def test_postgresql_uses_zero_scale_for_amount_columns
    assert_equal 0, Holding.columns_hash.fetch("amount_atomic").scale
  end

  def test_postgresql_uses_given_numeric_precision_for_amount_columns
    assert_equal 40, Holding.columns_hash.fetch("reserve_atomic").precision
  end

  def test_postgresql_uses_zero_scale_for_amount_columns_with_given_precision
    assert_equal 0, Holding.columns_hash.fetch("reserve_atomic").scale
  end

  def test_postgresql_where_query_works_with_amount_columns
    usdc = create_usdc_and_usd_holdings

    assert_equal [usdc.id], Holding.where_amount("USDC|1.50").pluck(:id)
  end

  def test_postgresql_group_query_works_with_amount_columns
    create_usdc_and_usd_holdings

    assert_equal({ "USDC" => 1_500_000, "USD" => 300 }, Holding.group(:amount_symbol).sum(:amount_atomic))
  end

  private

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
    load File.join(DUMMY_ROOT, "db/schema.rb")
    Holding.reset_column_information
  end
end
