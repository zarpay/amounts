# frozen_string_literal: true

module RuboCop
  module Cop
    module Amounts
      # A test file defines exactly one top-level class, its test class, and a
      # spec file has exactly one top-level `describe` (see
      # `.claude/rules/tests.md`). Test models, fake subclasses and helper
      # modules belong in `test/support/` or `spec/support/`. Classes nested
      # inside the test class are fine.
      #
      # @example
      #   # bad: test/amount/concerns/arithmetic_test.rb
      #   class GoldAmount < Amount; end
      #   class AmountArithmeticTest < Minitest::Test; end
      #
      #   # good
      #   class AmountArithmeticTest < Minitest::Test
      #     class GoldAmount < Amount; end
      #   end
      class OneTestClassPerFile < Base
        MSG_TEST = "Define exactly one top-level class per test file (found %<count>d); move helpers to test/support/."
        MSG_TEST_MODULE = "Define the test as a top-level class, not a module; move helper modules to test/support/."
        MSG_SPEC = "Define exactly one top-level `describe` per spec file (found %<count>d)."
        MSG_SPEC_DEFINITION = "Don't define top-level classes or modules in a spec file; move them to spec/support/."

        def on_new_investigation
          nodes = top_level_nodes
          if processed_source.file_path.to_s.end_with?("_spec.rb")
            check_spec(nodes)
          else
            check_test(nodes)
          end
        end

        private

        def top_level_nodes
          root = processed_source.ast
          return [] unless root

          root.begin_type? ? root.children : [root]
        end

        def check_test(nodes)
          definitions = nodes.select { |node| node.class_type? || node.module_type? }
          definitions.select(&:module_type?).each { |node| add_offense(node.loc.keyword, message: MSG_TEST_MODULE) }
          return if definitions.size == 1

          message = format(MSG_TEST, count: definitions.size)
          return add_global_offense(message) if definitions.empty?

          definitions.drop(1).each { |node| add_offense(node.loc.keyword, message:) }
        end

        def check_spec(nodes)
          nodes.select { |node| node.class_type? || node.module_type? }
               .each { |node| add_offense(node.loc.keyword, message: MSG_SPEC_DEFINITION) }

          describes = nodes.select { |node| describe_block?(node) }
          return if describes.size == 1

          message = format(MSG_SPEC, count: describes.size)
          return add_global_offense(message) if describes.empty?

          describes.drop(1).each { |node| add_offense(node.send_node, message:) }
        end

        def describe_block?(node)
          return false unless node.block_type?

          call = node.send_node
          call.method?(:describe) && (call.receiver.nil? || call.receiver.const_name == "RSpec")
        end
      end
    end
  end
end
