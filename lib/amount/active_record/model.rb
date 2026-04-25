# frozen_string_literal: true

class Amount
  module ActiveRecord
    # Provides `has_amount` for ActiveRecord models.
    module Model
      def has_amount(name, symbol: nil)
        definition = AttributeDefinition.new(name, symbol:)
        amount_attribute_definitions[definition.name] = definition

        define_amount_reader(definition)
        define_amount_writer(definition)
        define_amount_dirty_tracking(definition)
        define_amount_scopes(definition)
        define_amount_validation(definition)
      end

      def amount_attribute_definitions
        @amount_attribute_definitions ||= {}
      end

      def amount_component_columns(name)
        amount_attribute_definition(name).component_columns
      end

      def amount_atomic_column(name)
        amount_attribute_definition(name).atomic_column
      end

      def amount_symbol_column(name)
        amount_attribute_definition(name).symbol_column
      end

      private

      def amount_attribute_definition(name)
        amount_attribute_definitions.fetch(name.to_sym)
      end

      def define_amount_reader(definition)
        define_method(definition.name) do
          definition.read(self)
        end
      end

      def define_amount_writer(definition)
        define_method("#{definition.name}=") do |value|
          clear_amount_assignment_error(definition.name)
          definition.write(self, definition.type.cast(value))
        rescue ::Amount::Error, ArgumentError => error
          remember_amount_assignment_error(definition.name, error.message)
        end
      end

      def define_amount_dirty_tracking(definition)
        define_method("#{definition.name}_changed?") do
          definition.changed?(self)
        end

        define_method("#{definition.name}_was") do
          definition.value_in_database(self)
        end

        define_method("#{definition.name}_change") do
          definition.change(self)
        end

        define_method("saved_change_to_#{definition.name}?") do
          definition.saved_change?(self)
        end

        define_method("saved_change_to_#{definition.name}") do
          definition.saved_change(self)
        end

        define_method("#{definition.name}_before_last_save") do
          definition.before_last_save(self)
        end
      end

      def define_amount_scopes(definition)
        define_method("where_#{definition.name}") do |value|
          self.class.public_send("where_#{definition.name}", value)
        end

        scope :"where_#{definition.name}", lambda { |value|
          definition.query_relation(self, value)
        }

        scope :"where_#{definition.name}_gt", lambda { |value|
          definition.greater_than_relation(self, value)
        }

        scope :"where_#{definition.name}_gte", lambda { |value|
          definition.greater_than_or_equal_relation(self, value)
        }

        scope :"where_#{definition.name}_lt", lambda { |value|
          definition.less_than_relation(self, value)
        }

        scope :"where_#{definition.name}_lte", lambda { |value|
          definition.less_than_or_equal_relation(self, value)
        }

        scope :"where_#{definition.name}_between", lambda { |lower, upper|
          definition.between_relation(self, lower, upper)
        }

        return if definition.fixed_symbol?

        scope :"#{definition.name}_in", lambda { |symbol|
          definition.currency_relation(self, symbol)
        }
      end

      def define_amount_validation(definition)
        validate do
          definition.validate(self)
        end
      end
    end

    module InstanceMethods
      private

      def pending_amount_assignment_errors
        @pending_amount_assignment_errors ||= {}
      end

      def remember_amount_assignment_error(name, message)
        pending_amount_assignment_errors[name.to_sym] = message
      end

      def clear_amount_assignment_error(name)
        pending_amount_assignment_errors.delete(name.to_sym)
      end
    end
  end
end
