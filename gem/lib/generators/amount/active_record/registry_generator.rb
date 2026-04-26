# frozen_string_literal: true

require "rails/generators"

class Amount
  module ActiveRecord
    class RegistryGenerator < ::Rails::Generators::Base
      namespace "amounts:registry"

      source_root File.expand_path("templates", __dir__)
      VALID_PRESETS = %i[fiat metals crypto all].freeze

      argument :preset, type: :string, banner: "fiat|metals|crypto|all"

      def create_initializer
        template "registry.rb.tt", "config/initializers/amounts.rb"
      end

      private

      def preset_key
        @preset_key ||= begin
          key = preset.to_s.downcase.to_sym
          if VALID_PRESETS.include?(key)
            key
          else
            raise ::Thor::Error,
                  "unknown preset #{preset.inspect}; choose one of: fiat, metals, crypto, all"
          end
        end
      end

      def preset_categories
        preset_key == :all ? %i[fiat metals crypto] : [preset_key]
      end

      def preset_name
        preset_key.to_s
      end

      def registered_symbols
        @registered_symbols ||= preset_body.scan(/Amount\.register :([A-Z0-9_]+),/).flatten
      end

      def registry_guard_symbol
        registered_symbols.first
      end

      def preset_body
        @preset_body ||= File.read(
          File.join(self.class.source_root, "presets", "#{preset_name}.fragment")
        ).chomp
      end

      def preset_source_label
        preset_name
      end
    end
  end
end
