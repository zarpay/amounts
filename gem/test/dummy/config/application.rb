# frozen_string_literal: true

require "rails"
require "active_model/railtie"
require "active_record/railtie"

# What Bundler.require does in an app: the railtie then loads the adapter.
require_relative "../../../lib/amounts"

module Dummy
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.secret_key_base = "amounts-test-secret-key-base"
    config.hosts.clear
    config.active_support.deprecation = :stderr
  end
end
