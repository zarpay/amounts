# frozen_string_literal: true

module RuboCop
  module Cop
    module Amounts
      # Each test makes exactly one top-level assertion (see
      # `.claude/rules/tests.md`).
      #
      # Checks Minitest `def test_*` methods and `define_method` blocks, and
      # RSpec `it` / `specify` / `example` blocks. An assertion is a
      # receiver-less `assert*` / `refute*` / `flunk` call (Minitest) or
      # `expect` / `is_expected` (RSpec). Calls nested inside an assertion's
      # arguments or block, as in `expect { expect(x).to ... }.to raise_error`,
      # are part of that assertion.
      #
      # @example
      #   # bad
      #   def test_reader
      #     assert_equal 1, amount.atomic
      #     assert_equal :USDC, amount.symbol
      #   end
      #
      #   # good
      #   def test_reader_atomic
      #     assert_equal 1, amount.atomic
      #   end
      #
      #   def test_reader_symbol
      #     assert_equal :USDC, amount.symbol
      #   end
      class OneAssertionPerTest < Base
        MSG = "Make exactly one assertion per test (found %<count>d)."
        MINITEST_ASSERTION = /\A(?:assert|refute)(?:_|\z)|\Aflunk\z/
        RSPEC_ASSERTIONS = %i[expect is_expected].freeze
        RSPEC_EXAMPLES = %i[it specify example].freeze

        def on_def(node)
          return unless node.method_name.start_with?("test_")

          check(node.loc.name, node.body, :minitest)
        end

        def on_block(node)
          send_node = node.send_node
          return if send_node.receiver

          if send_node.method?(:define_method)
            check(send_node, node.body, :minitest)
          elsif RSPEC_EXAMPLES.include?(send_node.method_name)
            check(send_node, node.body, :rspec)
          end
        end
        alias on_numblock on_block

        private

        def check(range, body, style)
          count = count_assertions(body, style)
          return if count == 1

          add_offense(range, message: format(MSG, count:))
        end

        def count_assertions(node, style)
          return 0 unless node.is_a?(::RuboCop::AST::Node)
          return 1 if assertion?(node, style)

          node.children.sum { |child| count_assertions(child, style) }
        end

        def assertion?(node, style)
          call = node.block_type? || node.numblock_type? ? node.send_node : node
          return false unless call.send_type? && call.receiver.nil?

          if style == :rspec
            RSPEC_ASSERTIONS.include?(call.method_name)
          else
            MINITEST_ASSERTION.match?(call.method_name)
          end
        end
      end
    end
  end
end
