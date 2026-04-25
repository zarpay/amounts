# frozen_string_literal: true

require "active_record"

require_relative "../amount"
require_relative "active_record/attribute_definition"
require_relative "active_record/amount_validator"
require_relative "active_record/type"
require_relative "active_record/migration_methods"
require_relative "active_record/model"

class Amount
  # Optional Rails integration for ActiveRecord models and migrations.
  #
  # This file is intentionally opt-in. Requiring `"amount/active_record"`
  # extends ActiveRecord table definitions with `t.amount` and models with
  # `has_amount`.
  #
  # @example Loading the integration in a Rails app
  #   require "amount/active_record"
  #
  #   class Holding < ApplicationRecord
  #     has_amount :amount
  #     has_amount :fee, symbol: :SOL
  #   end
  module ActiveRecord
    # Installs the migration DSL and model macros into ActiveRecord.
    #
    # This is called automatically when the file is required.
    #
    # @return [void]
    def self.install!
      ::ActiveRecord::ConnectionAdapters::TableDefinition.include(MigrationMethods)
      if defined?(::ActiveRecord::ConnectionAdapters::Table)
        ::ActiveRecord::ConnectionAdapters::Table.include(MigrationMethods)
      end

      ::ActiveRecord::Base.extend(Model)
      ::ActiveRecord::Base.include(InstanceMethods)
    end
  end
end

Amount::ActiveRecord.install!
