# =============================================================================
# spec_helper.rb — configuration shared by every spec
# =============================================================================
#
# Loaded automatically via the `--require spec_helper` line in `.rspec`.
# Keep this file Rails-free: anything that needs ActiveRecord, the model
# layer, or the gem's RSpec matchers belongs in `rails_helper.rb`.
#
# Notable choices in this file:
#
#   - SimpleCov is started before any application code is loaded so the
#     coverage tool can instrument every file as it's required.
#
#   - `define_derived_metadata` flips `aggregate_failures` on by default.
#     This lets a single example assert several things and still report
#     every mismatch in one run, which is especially useful for the
#     gem's matchers (have_amount_column verifies multiple columns at once).
#
#   - `disable_monkey_patching!` enforces the `expect(...)` syntax. The
#     legacy `should ...` syntax is unavailable. This is a project-wide
#     style choice that this harness opts into.

require "simplecov"
SimpleCov.start "rails" do
  add_filter %r{^/config/}
  add_filter %r{^/spec/}
  add_group "Models",       "app/models"
  add_group "Initializers", "config/initializers"
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior      = :apply_to_host_groups
  config.filter_run_when_matching              :focus
  config.example_status_persistence_file_path  = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = false
  config.default_formatter = "doc" if config.files_to_run.one?
  config.profile_examples = 5
  config.order = :random
  Kernel.srand config.seed

  # aggregate_failures defaults to ON unless an example opts out.
  # See spec/matchers/gem_matchers_spec.rb for one example that disables it.
  config.define_derived_metadata do |meta|
    meta[:aggregate_failures] = true unless meta.key?(:aggregate_failures)
  end
end
