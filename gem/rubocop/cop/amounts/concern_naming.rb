# frozen_string_literal: true

module RuboCop
  module Cop
    module Amounts
      # A concern (a module directly inside `class Amount` in
      # `lib/amount/concerns/`) is named as an -able / -ible adjective, doesn't
      # reuse a Ruby core module's name, and lives in the file named after it
      # (see `.claude/rules/concerns.md`).
      #
      # @example
      #   # bad: lib/amount/concerns/arithmetic.rb
      #   class Amount
      #     module Arithmetic; end
      #   end
      #
      #   # bad: hides ::Comparable inside Amount and its subclasses
      #   class Amount
      #     module Comparable; end
      #   end
      #
      #   # good: lib/amount/concerns/calculable.rb
      #   class Amount
      #     module Calculable; end
      #   end
      class ConcernNaming < Base
        MSG_SUFFIX = "Name concerns as -able / -ible adjectives (`Calculable`, `Formattable`), not `%<name>s`."
        MSG_CORE = "`%<name>s` hides Ruby's `::%<name>s` inside Amount; pick another -able name."
        MSG_FILE = "Concern `%<name>s` belongs in concerns/%<file>s.rb."
        SUFFIX = /(?:able|ible)\z/

        def on_module(node)
          return unless node.parent_module_name == "Amount"

          name = node.identifier.short_name.to_s
          add_offense(node.identifier, message: format(MSG_SUFFIX, name:)) unless SUFFIX.match?(name)
          add_offense(node.identifier, message: format(MSG_CORE, name:)) if core_module?(name)
          check_file_name(node, name)
        end

        private

        def core_module?(name)
          ::Object.const_defined?(name, false) && ::Object.const_get(name, false).is_a?(::Module)
        end

        def check_file_name(node, name)
          file = name.gsub(/(?<!^)(?=[A-Z])/, "_").downcase
          return if File.basename(processed_source.file_path.to_s, ".rb") == file

          add_offense(node.identifier, message: format(MSG_FILE, name:, file:))
        end
      end
    end
  end
end
