# Changelog

The client is versioned in lockstep with the gem: `@zarpay/amounts` X.Y.Z
mirrors the `amounts` gem X.Y.Z, and both ship from the same GitHub Release.
Upgrade them together.

## 0.3.0 - 2026-11-15

### Added

- `@zarpay/amounts`: the `amounts` gem's core in TypeScript and JavaScript, for
  the web and React Native, built from the gem's `Amount.manifest` export.
  `Amounts.fromManifest` gives a client with `of`, `parse`, `parseUi` and
  `load`. `Amount` has the gem's arithmetic, comparison, conversion, splitting
  and allocation, serialization (`toHash`, `toJSON`, `toString`, `formatted`)
  and display (`ui`, `unitLabel`, `displayFormat`, `inUnit`), with locales
  read from the manifest. Values are `bigint` atomics and exact fractions
  (`Ratio`). No runtime dependencies. ESM, CommonJS and TypeScript
  declarations.
