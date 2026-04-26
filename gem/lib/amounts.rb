# frozen_string_literal: true

# Thin gem-name entrypoint for Bundler auto-require.
# Core users should still require "amount" directly.
require_relative "amount"

begin
  require "rails/railtie"
  require_relative "amount/active_record/railtie"
rescue LoadError
  nil
end
