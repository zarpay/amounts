# frozen_string_literal: true

class Amount
  # Internal: templates that place a formatted number and its unit label, in
  # the style of Rails' `number.currency.format.format`.
  #
  # `%n` stands for the formatted number, sign included, and `%u` for the unit
  # label. Everything else in a template is copied as given, so a non-breaking
  # space (`"%n %u"`) stays non-breaking.
  #
  # @example
  #   DisplayFormat.apply("%n %u", number: "12,50", label: "€")  # => "12,50 €"
  #   DisplayFormat.for_position(:prefix)                              # => "%u%n"
  module DisplayFormat
    NUMBER = "%n"
    LABEL = "%u"
    PREFIX = "%u%n"
    SUFFIX = "%n %u"

    PLACEHOLDER = /%[nu]/
    private_constant :PLACEHOLDER

    module_function

    # The template a `display_position` stands for: `:prefix` is `"%u%n"`,
    # anything else `"%n %u"`, matching the output before templates existed.
    # @param position [Symbol, nil]
    # @return [String]
    def for_position(position)
      position == :prefix ? PREFIX : SUFFIX
    end

    # A usable template is a String that places the number.
    # @param template [Object]
    # @return [Boolean]
    def valid?(template)
      template.is_a?(String) && template.include?(NUMBER)
    end

    # Fills a template in one pass, so a `%` inside the number or label is
    # never read as a placeholder.
    # @param template [String]
    # @param number [String] the formatted number
    # @param label [String] the unit label
    # @return [String]
    def apply(template, number:, label:)
      template.gsub(PLACEHOLDER, NUMBER => number, LABEL => label)
    end
  end
end
