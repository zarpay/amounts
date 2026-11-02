# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/amount/active_record"

class AmountActiveRecordTest < Minitest::Test
  def test_locale_file_is_loaded_once
    Amount::ActiveRecord.install_locale!

    assert_equal 1, I18n.load_path.count(Amount::ActiveRecord::LOCALE_PATH)
  end
end
