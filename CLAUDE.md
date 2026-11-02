# amounts

A Ruby gem for precise quantities of fungible things (money, tokens, commodities, units).
Values are arbitrary-precision atomic `Integer`s, types live in a registry, cross-type math
needs an explicit directional rate, and ActiveRecord support is an optional adapter.
Published to RubyGems as `amounts`.

## Layout

Three independent packages, each with its own Gemfile and dependencies:

| Path | What it is |
|---|---|
| `gem/` | The published gem: `lib/`, `test/` (Minitest), `spec/` (RSpec matchers), gemspec, `CHANGELOG.md` |
| `demo/` | A Rails 8.1 app that exercises every public feature against `../gem` (path-pinned). Its specs are the integration suite |
| `site/` | The VitePress docs at https://zarpay.github.io/amounts/, deployed from `main` by `docs.yml` |

## Commands

From `gem/`, matching CI (`.github/workflows/ci.yml`):

```sh
bundle exec ruby -Ilib:test test/test_amount.rb              # core Minitest
bundle exec rspec spec/amount_rspec_matchers_spec.rb         # core RSpec matchers
bundle exec ruby -Ilib:test test/test_active_record.rb       # ActiveRecord adapter
bundle exec rspec spec/active_record_rspec_matchers_spec.rb  # ActiveRecord matchers
bundle exec ruby -Ilib:test test/test_registry_generator.rb  # Rails generator
bundle exec rake lint                                        # RuboCop; must be clean
```

`bundle exec rake` alone does not run the Minitest files above: its test pattern is
`test/**/*_test.rb`. Run them directly. The PostgreSQL integration test needs
`AMOUNTS_POSTGRES_URL` and skips without it.

From `demo/`: `bin/rails db:migrate RAILS_ENV=test && bundle exec rspec`.
From `site/`: `npm install && npm run build`.

Finish every gem change with the gem commands passing, and the demo suite too when public
behavior changes.

## Rules that shape the code

- **The core is Rails-agnostic.** Only `lib/amount/active_record.rb`, `lib/amount/active_record/`,
  `lib/generators/` and the guarded railtie hook in `lib/amounts.rb` may load Rails,
  ActiveRecord or ActiveSupport.
- **Ruby 3.1 is the floor** for `gem/` (CI runs 3.1 to 3.4; RuboCop targets 3.1). Don't use
  newer syntax there, even though `demo/` runs on a newer Ruby.
- **Values stay exact.** Store and compute on atomic integers. A `Float` input is converted
  through its string form on the way in; never compute with or store a `Float`.
- **No implicit cross-type math.** Mixing types needs an explicit directional rate; don't add
  shortcuts around that.
- **Display units are not conversions.** Keep the two separate.
- **Behavioral changes need tests** in `gem/test` (and `gem/spec` for matchers). When public
  behavior or API changes, update `gem/README.md`, the relevant `site/` page, and the `demo/`
  if it covers that feature.

## Changelog and releases

- Add an entry to `gem/CHANGELOG.md` under a `## Unreleased` heading (create it at the top if
  missing), grouped as `### Added` / `### Changed` / `### Fixed`. Mark breaking changes
  **Breaking:** and include migration notes.
- Don't bump `Amount::VERSION` or move entries out of Unreleased. Versioning and releases are
  done by a maintainer: a GitHub Release triggers `release.yml`, which publishes to RubyGems.
- Never tag, release, publish the gem, or deploy the demo (`demo/.kamal`).
