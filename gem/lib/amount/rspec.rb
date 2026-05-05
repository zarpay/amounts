# frozen_string_literal: true

require_relative "../amount"
require "rspec/expectations"
require_relative "rspec/support"
require_relative "rspec/matchers"

# Opt-in RSpec matchers for `Amount`.
#
# Applications enable these matchers explicitly in their spec helper:
#
# @example
#   require "amount/rspec"
#
#   expect(Amount.of_usdc("1.50")).to eq_amount("USDC|1.50")
#   expect(Amount.of_usdc("1.50")).to be_amount_of(:USDC)
#   expect(Amount.of_usdc("1.50")).to be_positive_amount
#   expect(Amount.of_usdc("1.55")).to be_approximately_amount(:USDC, "1.50", within: "0.10")
Amount::RSpec::Matchers.define_amount_equality_matcher(:eq_amount) do |*expected_arguments|
  Amount::RSpec::Support.coerce_amount_arguments(expected_arguments)
end

Amount::RSpec::Matchers.define_amount_type_matcher
Amount::RSpec::Matchers.define_approximate_amount_matcher
Amount::RSpec::Matchers.define_amount_predicate_matcher(:be_zero_amount, "a zero Amount", &:zero?)
Amount::RSpec::Matchers.define_amount_predicate_matcher(:be_positive_amount, "a positive Amount", &:positive?)
Amount::RSpec::Matchers.define_amount_predicate_matcher(:be_negative_amount, "a negative Amount", &:negative?)
