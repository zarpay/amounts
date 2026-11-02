# frozen_string_literal: true

class Amount
  # Concern: where the number and its unit label go in decorated output.
  #
  # A format is a template in the style of Rails' `number.currency.format.format`:
  # `%n` is the formatted number (sign included) and `%u` the unit label.
  # Everything else is copied as given, so a non-breaking space in
  # `"%n %u"` stays non-breaking.
  #
  # Included in {Amount}, it answers one question per amount, {#display_format}:
  # which template does decorated `ui` output use, for this type or one of its
  # display units, in this locale? The module functions are the template
  # primitives the registry (validation) and {Display} (filling) share.
  #
  # A template is resolved, first match wins:
  #
  # - type: `amounts.formats.<symbol downcased>` (when localizing), then the
  #   registered `display_format`, which the registry derives from
  #   `display_position` when no template was given.
  # - display unit: `amounts.display_unit_formats.<symbol downcased>.<unit>`
  #   (when localizing), then the unit's `:format`, then its `:position`, then
  #   the type's template as above.
  #
  # A locale template without `%n` is ignored, so a typo in a locale file can't
  # drop the amount from the output.
  #
  # @example
  #   Amount.register :EUR, decimals: 2, display_symbol: "€", display_format: "%u%n"
  #   # de.yml: amounts.formats.eur: "%n %u"
  #
  #   Amount.of_eur("1").display_format               # => "%u%n"
  #   Amount.of_eur("1").display_format(locale: :de)  # => "%n %u"
  #   Amount::Formattable.fill("%n %u", number: "12,50", label: "€")
  #   # => "12,50 €"
  module Formattable
    NUMBER = "%n"
    LABEL = "%u"
    PREFIX = "%u%n"
    SUFFIX = "%n %u"

    PLACEHOLDER = /%[nu]/
    private_constant :PLACEHOLDER

    # The template a `display_position` stands for: `:prefix` is `"%u%n"`,
    # anything else `"%n %u"`, matching the output before templates existed.
    # @param position [Symbol, nil]
    # @return [String]
    def self.template_for(position)
      position == :prefix ? PREFIX : SUFFIX
    end

    # A usable template is a String that places the number.
    # @param template [Object]
    # @return [Boolean]
    def self.valid_template?(template)
      template.is_a?(String) && template.include?(NUMBER)
    end

    # Fills a template in one pass, so a `%` inside the number or label is
    # never read as a placeholder.
    # @param template [String]
    # @param number [String] the formatted number
    # @param label [String] the unit label
    # @return [String]
    def self.fill(template, number:, label:)
      template.gsub(PLACEHOLDER, NUMBER => number, LABEL => label)
    end

    # The template decorated `ui` output uses for this amount.
    #
    # @param unit [Symbol, nil] a display unit, or `nil` for the type itself
    # @param locale [Symbol, String, nil] look for a locale template too
    #   (requires I18n). When `nil`, uses `I18n.locale` if `Amount.localize`
    #   is true, else only the registered templates.
    # @return [String]
    # @raise [Registry::InvalidDisplayUnit] for an unknown display unit
    # @example
    #   Amount.of_usd("1").display_format                    # => "%u%n"
    #   Amount.of_gold("1").display_format(unit: :gram)      # => "%n %u"
    def display_format(unit: nil, locale: nil)
      locale = Locale.effective(locale)
      return type_display_format(locale) unless unit

      spec = registry_entry.display_unit(unit)
      (locale && locale_display_format(unit_format_key(unit), locale)) ||
        spec[:format] ||
        (spec[:position] && Formattable.template_for(spec[:position])) ||
        type_display_format(locale)
    end

    private

    def type_display_format(locale)
      (locale && locale_display_format(type_format_key, locale)) ||
        registry_entry.display_format
    end

    def locale_display_format(key, locale)
      found = Locale.translate(key, locale, nil)
      found if Formattable.valid_template?(found)
    end

    def type_format_key
      "amounts.formats.#{symbol.to_s.downcase}"
    end

    def unit_format_key(unit)
      "amounts.display_unit_formats.#{symbol.to_s.downcase}.#{unit}"
    end
  end
end
