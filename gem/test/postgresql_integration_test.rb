# frozen_string_literal: true

require_relative "test_helper"

begin
  require "pg"
rescue LoadError
  # Handled in setup.
end

ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
require "active_record/tasks/database_tasks"

class PostgreSQLIntegrationTest < Minitest::Test
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

  def test_postgresql_uses_numeric_precision_for_amount_columns
    columns = Holding.columns_hash

    assert_equal 78, columns.fetch("amount_atomic").precision
    assert_equal 0, columns.fetch("amount_atomic").scale
    assert_equal 40, columns.fetch("reserve_atomic").precision
    assert_equal 0, columns.fetch("reserve_atomic").scale
  end

  def test_postgresql_where_and_group_queries_work_with_amount_columns
    usdc = Holding.create!(amount: "USDC|1.50")
    Holding.create!(amount: "USD|3.00")

    assert_equal [usdc.id], Holding.where_amount("USDC|1.50").pluck(:id)
    assert_equal({ "USDC" => 1_500_000, "USD" => 300 }, Holding.group(:amount_symbol).sum(:amount_atomic))
  end

  private

  def configure_database_tasks
    ActiveRecord::Tasks::DatabaseTasks.database_configuration = Rails.application.config.database_configuration
    ActiveRecord::Tasks::DatabaseTasks.db_dir = File.expand_path("dummy/db", __dir__)
    ActiveRecord::Tasks::DatabaseTasks.env = "test"
    ActiveRecord::Tasks::DatabaseTasks.root = File.expand_path("dummy", __dir__)
  end

  def recreate_schema!
    ActiveRecord::Base.establish_connection(:test)
    load File.expand_path("dummy/db/schema.rb", __dir__)
    Holding.reset_column_information
  end
end
