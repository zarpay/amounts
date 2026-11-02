---
paths:
  - "gem/test/**/*"
  - "gem/spec/**/*"
  - "gem/Rakefile"
---

# Tests: one class per file, mirrored paths, one assertion per test

These rules have no exceptions beyond the ones listed here. Each one is enforced by a
project cop in `gem/rubocop/cop/amounts/`, run by `bundle exec rake lint`:

| Rule | Cop |
|---|---|
| One test class per file | `Amounts/OneTestClassPerFile` |
| Mirror the lib tree | `Amounts/MirroredTestPath` |
| One assertion per test | `Amounts/OneAssertionPerTest` |

Enforce new rules like these with a cop, not with runtime hooks in the test suite.

## One test class per file

A test file defines exactly one `Minitest::Test` subclass. A spec file has exactly one
top-level `RSpec.describe`. Test models, schemas, fake subclasses and shared helpers
go in `gem/test/support/` (required from the test file), never as extra top-level
classes in a test file. Classes nested inside the test class (such as
`class GoldAmount < Amount` used only by that test class) are fine.

## Mirror the lib tree

Each test file mirrors the file under test, with a `_test.rb` suffix. The class is
named after the constant under test, with `::` removed and `Test` appended:

| Under test | Test file | Test class |
|---|---|---|
| `lib/amount.rb` | `test/amount_test.rb` | `AmountTest` |
| `lib/amount/concerns/calculable.rb` | `test/amount/concerns/calculable_test.rb` | `AmountCalculableTest` |
| `lib/amount/ui_parser.rb` | `test/amount/ui_parser_test.rb` | `AmountUiParserTest` |
| `lib/amount/active_record/type.rb` | `test/amount/active_record/type_test.rb` | `AmountActiveRecordTypeTest` |
| `lib/generators/amount/active_record/registry_generator.rb` | `test/generators/amount/active_record/registry_generator_test.rb` | `AmountActiveRecordRegistryGeneratorTest` |
| `lib/amount/rspec/matchers.rb` | `spec/amount/rspec/matchers_spec.rb` | `RSpec.describe Amount::RSpec::Matchers` |

Class names are flat (no `class Amount; class ArithmeticTest`), so `ActiveRecord`
inside a test always means `::ActiveRecord`.

Put a test in the file of the code that **owns the behavior**, not the entry point it
calls through: `Amount.parse_ui` lives in `Parsable`, but the rules it tests (delimiters,
labels, signs) are `UiParser`'s, so they go in `ui_parser_test.rb`. Behavior that only
exists in combination (a registered subclass surviving `+`) goes with the concern that
promises it (`Calculable`).

`Amounts/MirroredTestPath` checks that the lib file exists and that the class (or the
constant passed to `describe`) matches the path, ignoring case and underscores. The only
directories that don't mirror `lib/`, and are excluded from that cop in `.rubocop.yml`:

- `test/support/`: helpers, shared setup and test models
- `test/dummy/`: the Rails app the integration tests boot
- `test/integration/`: tests against an external system (PostgreSQL) that cover the
  whole stack rather than one file

## One assertion per test

A test makes exactly **one** top-level `assert_*` / `refute_*` call (one `expect` per
`it` in RSpec). `Amounts/OneAssertionPerTest` checks `def test_*`, `define_method`
blocks and `it` / `specify` blocks.

The cop sees only the test body, so it can't catch two things. Avoid both:

- an assertion inside a loop (`items.each { assert ... }`), which runs many times but
  counts once;
- a test body passed to a custom macro instead of `define_method`.

- **Shared arrange** goes in `setup` or a private helper, so the tests that check
  different facts about the same result stay one line each.
- **Several facts about one object** become several tests: `test_reader_returns_amount`
  and `test_reader_returns_amount_with_symbol`, not one test with two asserts.
- **Small tables of cases** become one test per row, generated at class level:

  ```ruby
  {
    "1,234.50" => 123_450,
    "1234.50" => 123_450
  }.each do |input, atomic|
    define_method("test_parses_#{input.tr('^a-zA-Z0-9', '_')}") do
      assert_equal atomic, Amount.parse_ui(input, :USD).atomic
    end
  end
  ```

  Test names must be unique, or a later `define_method` silently replaces an earlier one.
- **Properties over a large range** (thousands of round trips) are one assertion over the
  whole collection, which reports every failing value at once:
  `assert_equal inputs, inputs.map { |i| round_trip(i) }`.
- **An error and its message** are two tests: `assert_raises(Amount::InvalidInput) { ... }`
  in one, and `assert_match(/too many decimals/, error_from(Amount::InvalidInput) { ... }.message)`
  in the other. `error_from` (in `test/support/error_helpers.rb`) returns the
  raised error and isn't an assertion.
- Don't hide extra assertions in helpers. A helper arranges or computes, and the test asserts.

## Running

From `gem/`:

```sh
bundle exec rake test                  # all three groups below, each in its own process
bundle exec rake test:core             # test/amount_test.rb + test/amount/** except active_record (no Rails)
bundle exec rake test:active_record    # test/amount/active_record{_test.rb,/**} + test/generators/**
bundle exec rake test:integration      # test/integration/** (skips without AMOUNTS_POSTGRES_URL;
                                       # with it set, an unreachable database fails)
bundle exec rake spec                  # spec:core then spec:active_record, separate processes
bundle exec ruby -Ilib:test test/amount/concerns/calculable_test.rb   # one file
BUNDLE_GEMFILE=gemfiles/rails_7.1.gemfile bundle exec rake test:active_record   # one Rails version
```

The groups run in separate processes on purpose. ActiveSupport patches core classes,
so core tests must not share a process with Rails. The integration tests boot
`test/dummy`, whose `Holding` model collides with the SQLite test models.
