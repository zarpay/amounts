/**
 * `@zarpay/amounts` — exact amounts of money, tokens and commodities for
 * the web and React Native: the `amounts` gem's core, mirrored, and built
 * from the registry the gem exports with `Amount.manifest`.
 *
 * - {@link Amounts} — the client: build one from a manifest, then
 *   construct amounts with `of`, `parse`, `parseUi` and `load`
 * - {@link Amount} — one exact quantity: math, comparison, conversion,
 *   splitting, serialization and display
 * - {@link Ratio} — an exact fraction, the result of dividing two amounts
 * - {@link Registry} / {@link RegistryEntry} — what the server registered
 * - {@link AmountError} — every error, with a `code`
 *
 * @example
 *   import { Amounts } from "@zarpay/amounts";
 *
 *   const amounts = Amounts.fromManifest(manifest);
 *   const total = amounts.of("USDC", "19.99").multiply(3);
 *   total.ui();      // "$59.97"
 *   total.toJSON();  // "USDC|59.970000"
 *
 * @packageDocumentation
 */

export type * from "@/types/amount.js";
export type * from "@/types/manifest.js";
export type { AmountErrorCode } from "@/helpers/errors-helper.js";

export { AmountError } from "@/helpers/errors-helper.js";
export { Amount } from "@/models/amount.js";
export { Amounts } from "@/models/amounts.js";
export { Ratio } from "@/models/ratio.js";
export { Registry } from "@/models/registry.js";
export { RegistryEntry } from "@/models/registry-entry.js";
