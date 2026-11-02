# frozen_string_literal: true

module RuboCop
  module Cop
    module Amounts
      # A test file mirrors the lib file it tests, and its class is named after
      # that file (see `.claude/rules/tests.md`):
      #
      #   test/amount/ui_parser_test.rb            -> lib/amount/ui_parser.rb, AmountUiParserTest
      #   test/amount/concerns/arithmetic_test.rb  -> lib/amount/concerns/arithmetic.rb, AmountArithmeticTest
      #   test/generators/amount/active_record/registry_generator_test.rb
      #     -> lib/generators/amount/active_record/registry_generator.rb,
      #        AmountActiveRecordRegistryGeneratorTest
      #   spec/amount/rspec/matchers_spec.rb       -> lib/amount/rspec/matchers.rb,
      #                                               RSpec.describe Amount::RSpec::Matchers
      #
      # `concerns/` and the leading `generators/` are folders, not namespaces,
      # so they are left out of the name. Names compare without case or
      # underscores, so `RSpec` matches `rspec` and `UiParser` matches
      # `ui_parser`. Directories that don't mirror lib (`test/support`,
      # `test/integration`, ...) are excluded in `.rubocop.yml`.
      class MirroredTestPath < Base
        MSG_NO_LIB = "%<test>s doesn't mirror a lib file: expected %<lib>s to exist."
        MSG_NAME = "Name this %<kind>s after %<lib>s: expected `%<expected>s` (case-insensitive)."
        TEST_PATH = %r{\A(test|spec)/(generators/)?(.+)_(?:test|spec)\.rb\z}
        NAMESPACE_FREE_DIRS = %w[concerns].freeze

        def on_new_investigation
          relative = relative_path
          match = TEST_PATH.match(relative)
          return unless match

          kind, generators, stem = match.captures
          lib = "lib/#{generators}#{stem}.rb"
          return add_global_offense(format(MSG_NO_LIB, test: relative, lib:)) unless File.exist?(File.join(base_dir, lib))

          check_name(kind, stem, lib)
        end

        private

        def base_dir
          config.base_dir_for_path_parameters
        end

        def relative_path
          path = File.expand_path(processed_source.file_path.to_s)
          path.delete_prefix("#{File.expand_path(base_dir)}/")
        end

        def check_name(kind, stem, lib)
          segments = stem.split("/").reject { |segment| NAMESPACE_FREE_DIRS.include?(segment) }
          kind == "spec" ? check_spec_name(segments, lib) : check_test_name(segments, lib)
        end

        def check_test_name(segments, lib)
          node = test_class(top_level_nodes.select(&:class_type?))
          return unless node

          expected = "#{segments.map { |segment| camelize(segment) }.join}Test"
          return if normalize(node.identifier.const_name) == normalize(expected)

          add_offense(node.identifier, message: format(MSG_NAME, kind: "test class", lib:, expected:))
        end

        def check_spec_name(segments, lib)
          node = top_level_nodes.find { |candidate| candidate.block_type? && candidate.send_node.method?(:describe) }
          return unless node

          described = node.send_node.first_argument
          expected = segments.map { |segment| camelize(segment) }.join("::")
          return if described&.const_type? && normalize(described.const_name) == normalize(expected)

          add_offense(described || node.send_node, message: format(MSG_NAME, kind: "describe", lib:, expected:))
        end

        # The class ending in `Test`, else the first subclass, else the first
        # class. Extra classes are OneTestClassPerFile's to report.
        def test_class(classes)
          classes.find { |node| node.identifier.short_name.to_s.end_with?("Test") } ||
            classes.find(&:parent_class) || classes.first
        end

        def top_level_nodes
          root = processed_source.ast
          return [] unless root

          root.begin_type? ? root.children : [root]
        end

        def camelize(segment)
          segment.split("_").map(&:capitalize).join
        end

        def normalize(name)
          name.to_s.delete(":_").downcase
        end
      end
    end
  end
end
