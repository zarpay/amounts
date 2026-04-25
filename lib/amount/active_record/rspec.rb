# frozen_string_literal: true

require_relative "../active_record"
require "rspec/expectations"
require_relative "../rspec"

Amount::RSpecMatchers.define_amount_column_matcher
Amount::RSpecMatchers.define_amount_sum_matcher
