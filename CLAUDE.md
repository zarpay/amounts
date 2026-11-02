# amounts

A Ruby gem for precise quantities of fungible things (money, tokens, commodities, units).
Values are arbitrary-precision atomic `Integer`s, types live in a registry, cross-type math
needs an explicit directional rate, and ActiveRecord support is an optional adapter.
Published to RubyGems as `amounts`.

## Layout

Three independent packages, each with its own Gemfile and dependencies:

| Path | What it is |
|---|---|
| `gem/` | The published gem: `lib/` (concerns in `lib/amount/concerns/`), `test/` (Minitest, mirrors `lib/`), `spec/` (RSpec matchers), gemspec, `CHANGELOG.md` |
| `demo/` | A Rails 8.1 app that exercises every public feature against `../gem` (path-pinned). Its specs are the integration suite |
| `site/` | The VitePress docs at https://zarpay.github.io/amounts/, deployed from `main` by `docs.yml` |

## Commands

From `gem/`, matching CI (`.github/workflows/ci.yml`):

```sh
bundle exec rake test:core            # core Minitest (no Rails in the process)
bundle exec rake spec:core            # core RSpec matchers
bundle exec rake test:active_record   # ActiveRecord adapter + Rails generator
bundle exec rake spec:active_record   # ActiveRecord matchers
bundle exec rake test:integration     # PostgreSQL; skips without AMOUNTS_POSTGRES_URL
bundle exec rake lint                 # RuboCop; must be clean
bundle exec rake                      # all of the above
bundle exec ruby -Ilib:test test/amount/concerns/calculable_test.rb   # one file
```

CI runs the ActiveRecord suites, including PostgreSQL, once per Ruby (3.1 to 4.0) and Rails
version (7.1, 7.2, 8.0, 8.1; Rails 8 needs Ruby 3.2). Each Rails version has a gemfile and a
committed lockfile in `gem/gemfiles/`. Run one locally with
`BUNDLE_GEMFILE=gemfiles/rails_8.1.gemfile bundle exec rake test:active_record`. When you add
a Rails version, generate its lockfile on the oldest Ruby it supports, so the same lock
installs across the matrix. If that lock pins a native gem whose precompiled builds stop
before the newest Ruby (nokogiri and sqlite3 in the Rails 7.x gemfiles), mark it
`force_ruby_platform: true` so it builds from source.

From `demo/`: `bin/rails db:migrate RAILS_ENV=test && bundle exec rspec`.
From `site/`: `npm install && npm run build`.

Finish every gem change with the gem commands passing, and the demo suite too when public
behavior changes.

## Rules that shape the code

Detailed rules live in `.claude/rules/` and load when you touch the files they cover:
`concerns.md` (keeping `Amount` thin; where concerns go and their shape) and `tests.md`
(one test class per file, test paths mirror `lib/`, one assertion per test).

- **The core is Rails-agnostic.** Only `lib/amount/active_record.rb`, `lib/amount/active_record/`,
  `lib/generators/` and the guarded railtie hook in `lib/amounts.rb` may load Rails,
  ActiveRecord or ActiveSupport.
- **Ruby 3.1 is the floor** for `gem/` (CI runs 3.1 to 4.0; RuboCop targets 3.1). Don't use
  newer syntax there, even though `demo/` runs on a newer Ruby.
- **Values stay exact.** Store and compute on atomic integers. A `Float` input is converted
  through its string form on the way in; never compute with or store a `Float`.
- **No implicit cross-type math.** Mixing types needs an explicit directional rate; don't add
  shortcuts around that.
- **Display units are not conversions.** Keep the two separate.
- **`Amount` stays thin.** New behavior goes in a concern in `gem/lib/amount/concerns/`,
  not in `gem/lib/amount.rb`.
- **Behavioral changes need tests** in `gem/test` (and `gem/spec` for matchers), in the
  file that mirrors the code under test, one assertion per test. When public
  behavior or API changes, update `gem/README.md`, the relevant `site/` page, and the `demo/`
  if it covers that feature.

## Changelog and releases

- Add an entry to `gem/CHANGELOG.md` under a `## Unreleased` heading (create it at the top if
  missing), grouped as `### Added` / `### Changed` / `### Fixed`. Mark breaking changes
  **Breaking:** and include migration notes.
- Don't bump `Amount::VERSION` or move entries out of Unreleased. Versioning and releases are
  done by a maintainer: a GitHub Release triggers `release.yml`, which publishes to RubyGems.
- Never tag, release, publish the gem, or deploy the demo (`demo/.kamal`).
