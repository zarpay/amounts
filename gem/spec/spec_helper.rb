# frozen_string_literal: true

require_relative "../test/support/amount_test_support"
require_relative "../lib/amount"
require_relative "../lib/amount/rspec"

RSpec.configure do |config|
  config.before do
    AmountTestSupport.register_default_types!
  end

  config.after do
    Amount.registry.clear!
  end
end
