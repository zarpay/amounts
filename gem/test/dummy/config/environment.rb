# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../../Gemfile", __dir__)

require_relative "application"
Dummy::Application.initialize!
