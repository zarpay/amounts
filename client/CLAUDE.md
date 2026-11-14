# client

`@zarpay/amounts`: the gem's core, mirrored in TypeScript and built from the
registry the gem exports (`Amount.manifest`). Read `specs/` before changing
behavior: `01-surface.md` (what is mirrored and the deliberate differences),
`02-manifest.md` (the wire format), `03-interface.md` (the API).

## Commands

```sh
npm test                  # vitest run
npm test -- tests/models/amount.test.ts
npm run lint              # eslint src tests
npm run typecheck         # tsc --noEmit
npm run format            # prettier --write
npm run build             # tsup → dist/ (ESM, CJS, .d.ts)
```

Finish every change with all five passing. If the gem's export changes,
regenerate `tests/fixtures/manifest.json` from `gem/` with
`bundle exec ruby -Ilib ../client/tests/fixtures/export-manifest.rb`; CI fails
when the committed fixture differs from the gem's export.

## Versions and releases

The client has its own version, bumped only when the client changes; it isn't tied to the
gem's. What ties them is the manifest version: the client reads manifest version 1, and a gem
that changes the manifest's shape bumps it. Add entries to `CHANGELOG.md` under
`## Unreleased`; don't bump the version, tag or publish — a maintainer does, and
`.github/workflows/publish-npm.yml` publishes a new version to npm by trusted publishing, on a
GitHub Release or when run by hand.

## Rules that shape the code

The conventions are praxis-cli's (zarpay/praxis-cli `cli/CLAUDE.md` and
`.claude/rules/`), adapted to a library:

- **Parity first.** Every behavior mirrors a gem method; the file layout mirrors
  the gem's (`models/display.ts` ↔ `amount/display.rb`). A behavior the gem
  doesn't have doesn't go here. A deliberate difference goes in
  `specs/01-surface.md` with its reason.
- **Values stay exact.** Atomic values are `bigint`; every decimal (a UI value,
  scalar, rate, scale, displayed number) is a `Ratio`. Never compute with a
  `number`; a `number` input is read through its string form.
- **Zero runtime dependencies**, and nothing a React Native engine lacks: no
  Node APIs, no `Intl`, ES2020.
- **Object-oriented.** `models/` holds classes, validated on construction and
  frozen. `helpers/` holds plain functions below the models, and never imports
  one (ESLint-enforced). Errors come from `errors-helper.ts` factories, each
  with a code; never build an error string elsewhere.
- **Types:** shared types in `src/types/` behind the `src/types.ts` barrel;
  a type one module speaks stays unexported in it (ESLint-enforced). Names read
  as families (`AmountUiOptions`, `ManifestDisplayUnit`).
- **Legibility:** one call per expression and named intermediates, in code and
  in tests; no nested ternaries; conditionals have a blank line around them;
  imports use the `@/` and `@tests/` aliases.

## Tests

- `tests/` mirrors `src/` one-to-one; each file tests one module's public
  interface. Shared fixtures are in `tests/helpers/fixtures.ts`.
- **One assertion per test, each written out.** Never iterate over a table of
  cases.
- **Expected values come from the gem.** Run the same call against
  `tests/fixtures/registry.rb` in Ruby and copy its answer; never derive an
  expectation from the client's own output.
