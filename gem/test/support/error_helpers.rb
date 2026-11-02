# frozen_string_literal: true

require "minitest"

# Helpers for tests that assert on an error's message, so the raise and the
# message can be checked in separate single-assertion tests.
module ErrorHelpers
  # The error the block raises. Not an assertion: the test still asserts on
  # the result. Fails the test when nothing is raised.
  #
  # @param klass [Class<Exception>]
  # @return [Exception]
  def error_from(klass = StandardError)
    yield
  rescue klass => e
    e
  else
    raise Minitest::Assertion, "expected #{klass} to be raised, nothing was raised"
  end
end

Minitest::Test.include(ErrorHelpers)
