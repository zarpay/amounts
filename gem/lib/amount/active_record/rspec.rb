# frozen_string_literal: true

require_relative "../active_record"
require "rspec/expectations"
require_relative "../rspec"
require_relative "rspec/matchers"

Amount::ActiveRecord::RSpec::Matchers.define_amount_column_matcher
Amount::ActiveRecord::RSpec::Matchers.define_amount_sum_matcher
