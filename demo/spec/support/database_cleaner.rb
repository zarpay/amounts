# =============================================================================
# database_cleaner — opt-out path for examples that can't use a transaction
# =============================================================================
#
# Most specs run inside a transaction (configured in rails_helper.rb), which
# is fast and cleanly isolates examples from each other. A few specs need
# the database to be in a real committed state — for instance when
# verifying behavior across a write barrier or interacting with a forked
# process.
#
# Tag such an example with `:no_transaction`:
#
#   it "round-trips through a real commit", :no_transaction do
#     ...
#   end
#
# The hooks below disable the surrounding transaction for that example only
# and clean up via truncation afterwards.

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each, :no_transaction) do |example|
    self.use_transactional_tests = false if respond_to?(:use_transactional_tests=)
    DatabaseCleaner.strategy = :truncation
  end

  config.after(:each, :no_transaction) do
    DatabaseCleaner.clean
    DatabaseCleaner.strategy = :transaction
  end
end
