# =============================================================================
# rails_helper.rb — Rails-aware additions to spec_helper
# =============================================================================
#
# Required only by specs that need Rails / ActiveRecord / the gem's RSpec
# matchers. Pure value-object specs can stay on `require "spec_helper"`.
#
# Notable wiring:
#
#   - `require "amount/rspec"` brings in the gem's core matchers
#     (eq_amount, be_amount_of, be_zero_amount, etc.) — defined under
#     `Amount::RSpec::Matchers` since 0.0.4.
#
#   - `require "amount/active_record/rspec"` brings in the AR-specific
#     matchers (have_amount_column, match_amounts).
#
#   - `Dir[Rails.root.join("spec/support/**/*.rb")]` autoloads the
#     shared_context / shared_examples / database_cleaner helpers.
#
#   - `infer_spec_type_from_file_location!` lets `spec/models/foo_spec.rb`
#     pick up `type: :model` automatically — no metadata block needed.

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "amount/rspec"
require "amount/active_record/rspec"
require "shoulda/matchers"
require "database_cleaner/active_record"

Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library        :rails
  end
end

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join("spec/fixtures")]

  # Most specs run inside a transaction. The `:no_transaction` tag (see
  # spec/support/database_cleaner.rb) opts an example out — useful when
  # we need to verify behavior across a real commit boundary.
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  # FactoryBot's bare `create(...)` / `build(...)` syntax becomes available
  # without the `FactoryBot.` prefix.
  config.include FactoryBot::Syntax::Methods

  # Make every gem matcher available without `Amount::RSpec::Matchers.`
  # prefixing. This is the same surface a downstream app would expose.
  config.include Amount::RSpec::Matchers
end
