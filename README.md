# amounts

[![Gem Version](https://img.shields.io/gem/v/amounts)](https://rubygems.org/gems/amounts)
[![CI](https://github.com/zarpay/amounts/actions/workflows/ci.yml/badge.svg)](https://github.com/zarpay/amounts/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/zarpay/amounts)](https://github.com/zarpay/amounts/releases)
[![License](https://img.shields.io/github/license/zarpay/amounts)](https://github.com/zarpay/amounts/blob/main/LICENSE.txt)
[![Ruby](https://img.shields.io/badge/Ruby-%3E%3D%203.1-red)](https://rubygems.org/gems/amounts)

`amounts` is a Ruby gem for precise quantities of fungible things — money,
crypto tokens, commodities, inventory units, points, and similar
value-like amounts. It stores every value as an arbitrary-precision atomic
`Integer`, keeps type identity in a registry, rejects accidental cross-type
math unless an explicit directional rate exists, and offers an optional
ActiveRecord adapter without making Rails part of the core runtime.

## Repository layout

This repo is organized as three top-level packages:

| Directory | Purpose | README |
|---|---|---|
| [`gem/`](./gem) | The published gem source — `lib/`, `test/`, `spec/`, gemspec, `CHANGELOG.md`. Everything that ends up on RubyGems lives here. | [`gem/README.md`](./gem/README.md) |
| [`site/`](./site) | The VitePress documentation site published to <https://zarpay.github.io/amounts/>. | [`site/`](./site) |
| [`demo/`](./demo) | A Rails 8.1 case-study app that exercises every public feature of the gem. Annotated as a textbook so each file teaches something. | [`demo/README.md`](./demo/README.md) |

## Working in this repo

Each package is independent and uses its own Gemfile / dependencies.

```bash
# work on the gem
cd gem
bundle install
bundle exec rake          # full test + lint suite

# work on the docs site
cd site
npm install
npm run docs:dev          # local VitePress server

# work on the demo
cd demo
bundle install
bin/rails db:migrate RAILS_ENV=test
bundle exec rspec         # runs the harness against ../gem
bin/rails generate amounts:registry fiat
```

The demo's `Gemfile` path-pins `gem "amounts", path: "../gem"`, so changes
in `gem/` are immediately picked up by `bundle exec rspec` in `demo/`.
This makes the demo a real-time integration check during gem development.

## CI

Three GitHub workflows live in `.github/workflows/`:

| Workflow | Triggers | What it does |
|---|---|---|
| `ci.yml`      | push to `main`, every PR | Runs the gem's minitest + rspec across Ruby 3.1 – 3.4, runs the rubocop quality job, and runs the demo's full RSpec suite |
| `release.yml` | a published GitHub Release | Re-runs the gem suite on the tagged commit, then publishes the gem to RubyGems.org via OIDC trusted publishing |
| `docs.yml`    | push to `main` | Builds the VitePress site from `site/` and deploys it to GitHub Pages |

`ci.yml` and `release.yml` set `working-directory: gem` for Ruby steps so
the gem package builds in isolation; the docs workflow uses
`working-directory: site`; the demo job inside `ci.yml` switches to
`working-directory: demo`.

## Contributing

- Bug or feature in the gem → PR against `gem/`. Tests live in
  `gem/test/` (Minitest) and `gem/spec/` (RSpec). `bundle exec rake` runs
  both plus rubocop.
- Documentation site → PR against `site/`. The build is `npm run docs:build`.
- Application-level patterns or new integration scenarios → PR against
  `demo/`. The harness has its own README explaining the cookbook
  domains.

## License

[MIT](./gem/LICENSE.txt).
