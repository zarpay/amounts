# frozen_string_literal: true

require "i18n"

# Default types plus a fresh I18n backend with en, de and fr number formats,
# restored after each test.
module LocaleTestSetup
  def setup
    AmountTestSupport.register_default_types!
    @previous_locale = I18n.locale
    @previous_backend = I18n.backend
    I18n.backend = I18n::Backend::Simple.new
    I18n.available_locales = %i[en de fr xx]
    I18n.backend.store_translations(:en, number: { format: { delimiter: ",", separator: "." } })
    I18n.backend.store_translations(:de, number: { format: { delimiter: ".", separator: "," } })
    I18n.backend.store_translations(:fr, number: { format: { delimiter: " ", separator: "," } })
    Amount.localize = false
  end

  def teardown
    Amount.localize = false
    I18n.backend = @previous_backend
    I18n.locale = @previous_locale
    Amount.registry.clear!
  end

  private

  # Runs the block as if the i18n gem were not loaded.
  def without_i18n
    i18n = Object.send(:remove_const, :I18n)
    yield
  ensure
    Object.const_set(:I18n, i18n)
  end
end
