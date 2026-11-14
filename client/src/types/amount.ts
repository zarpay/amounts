/**
 * The shapes callers hand to and get back from the client's public API:
 * constructor inputs, option objects and payloads. See
 * specs/03-interface.md.
 */

import type { Label } from "@/types/manifest.js";

/**
 * A value for {@link Amounts.of}, read by its JavaScript type:
 *
 * - `bigint` — a count of atomic units (`1_500_000n` USDC is 1.50)
 * - `string` — whole units, read exactly (`"1.50"`, `"1_000"`, `"1e3"`)
 * - `number` — whole units, read through its string form (`1.5` is `"1.5"`)
 *
 * Pass `{ from }` to read one differently.
 */
export type AmountInput = bigint | number | string;

/**
 * An exact decimal: a scalar for `multiply`/`divide`, a rate for `to`, a
 * count for `unitLabel`. A `string` is read in Ruby's `BigDecimal` grammar,
 * a `number` through its string form (so `0.1` is exactly one tenth), a
 * `bigint` as itself. The client's stand-in for a `BigDecimal`.
 */
export type DecimalInput = bigint | number | string;

/**
 * How {@link Amounts.of} reads a value, overriding the inference by type
 * (the gem's `from:`): `"atomic"` for atomic units, `"ui"` for whole units.
 */
export type AmountInputFormat = "atomic" | "ui";

/** Options for {@link Amounts.of}. */
export interface AmountOfOptions {
  /**
   * Read the value as atomic units or whole units regardless of its type.
   * `"atomic"` accepts a `bigint`, a safe-integer `number`, or a string of
   * digits; `"ui"` accepts anything a whole-unit value can be.
   *
   * @example
   *   amounts.of("USDC", "1500000", { from: "atomic" });  // 1.50
   */
  from?: AmountInputFormat;
}

/**
 * The versioned payload {@link Amount.toHash} writes and
 * {@link Amounts.load} reads — the gem's `to_h`.
 */
export interface AmountHash {
  /** The payload version: `1`, or absent (read as 1). */
  v?: number | null;
  /** The atomic value: a digit string (as written), a `bigint`, or a safe integer. */
  atomic: bigint | number | string;
  /** The type's symbol. */
  symbol: string;
}

/**
 * Which way display rounding goes. `"floor"` (the default) rounds down so
 * an amount never displays as more than it is; `"ceil"` rounds up.
 */
export type RoundingDirection = "floor" | "ceil";

/**
 * The `compact` option of `ui`: `true` for compact notation with 3
 * significant digits, `{ precision }` for another number of digits, `false`
 * (the default) for none.
 */
export type CompactOption = boolean | { precision?: number };

/** Options for {@link Amount.ui}. Every option is optional; with none, `ui` uses the type's registered display settings. */
export interface AmountUiOptions {
  /**
   * Show the amount in one of the type's display units (troy ounces as
   * `"gram"`), with that unit's scale, decimals, label and template. The
   * amount is still the same type; only the display changes.
   *
   * @example
   *   amounts.of("GOLD", "1").ui({ unit: "gram" });  // "31.10 g"
   */
  unit?: string;
  /**
   * Round down (`"floor"`, the default) or up (`"ceil"`) to the display
   * decimals.
   *
   * @example
   *   amounts.of("USDC", "1.231").ui({ direction: "ceil" });  // "$1.24"
   */
  direction?: RoundingDirection;
  /**
   * `false` returns the number alone, for a layout that renders the label
   * separately (a column header, an input adornment). Defaults to `true`.
   *
   * @example
   *   amounts.of("USDC", "1.5").ui({ decorated: false });  // "1.50"
   */
  decorated?: boolean;
  /**
   * Strip trailing zeros after rounding (`"2.5 SOL"` instead of
   * `"2.5000 SOL"`). `true`/`false` override the setting; `null` or
   * omitted uses the display unit's, then the type's `trim_zeros`.
   */
  trimZeros?: boolean | null;
  /**
   * Format for a locale the manifest was exported with: its delimiter and
   * separator, its labels and templates, its compact words. Omitted or
   * `null` uses the client's locale, else plain output.
   *
   * @example
   *   amounts.of("USD", "1500.5").ui({ locale: "de" });  // "$1.500,50"
   */
  locale?: string | null;
  /**
   * Compact notation for numbers of one thousand or more: `true` for 3
   * significant digits, `{ precision: 2 }` for 2. Rounds in `direction`
   * and trims trailing zeros; the label and template still apply.
   *
   * @example
   *   amounts.of("USD", "1500000").ui({ compact: true });  // "$1.5M"
   */
  compact?: CompactOption;
}

/** Options for {@link Amount.unitLabel}. */
export interface AmountUnitLabelOptions {
  /** The label of one of the type's display units instead of the type's own. */
  unit?: string;
  /** Translate the label for this locale; omitted uses the client's locale. */
  locale?: string | null;
  /**
   * The number the label agrees with, for plural labels (`1` gives
   * `"search"`, `3` gives `"searches"`). Without it, the `other` form.
   */
  count?: DecimalInput;
}

/** Options for {@link Amount.displayFormat}. */
export interface AmountDisplayFormatOptions {
  /** The template of one of the type's display units instead of the type's own. */
  unit?: string;
  /** The template for this locale; omitted uses the client's locale. */
  locale?: string | null;
}

/** Options for {@link Amount.to}. */
export interface AmountToOptions {
  /**
   * The rate to convert at, instead of the registered default rate: one
   * unit of the source type is worth `rate` units of the target. Omitted
   * or `null` uses the default rate.
   *
   * @example
   *   amounts.of("USDC", "100").to("GOLD", { rate: "0.00042" });  // GOLD 0.04200000
   */
  rate?: DecimalInput | null;
}

/** Options for {@link Amounts.fromManifest}. */
export interface AmountsOptions {
  /**
   * The locale every call uses when it names none — the gem's
   * `Amount.localize = true` with `I18n.locale`. Must be a locale the
   * manifest was exported with. Omitted or `null` means plain output.
   */
  locale?: string | null;
}

/** Options for {@link Amounts.parseUi}. */
export interface AmountsParseUiOptions {
  /** Read the number in this locale's format; omitted uses the client's locale, else plain. */
  locale?: string | null;
}

/**
 * One display unit of a registered type, read from the manifest: a way to
 * show the type scaled (troy ounces as grams), never a different type.
 */
export interface DisplayUnit {
  /** How many of this unit make one whole unit of the type, as an exact decimal string. */
  readonly scale: string;
  /** The unit's label, or `null` to use the type's `display_symbol`. */
  readonly symbol: Label | null;
  /** Decimals `ui` shows in this unit, or `null` for the type's `ui_decimals`. */
  readonly uiDecimals: number | null;
  /** The unit's template (its `format`, or its `position` resolved), or `null` for the type's. */
  readonly format: string | null;
  /** Whether to trim trailing zeros in this unit, or `null` for the type's setting. */
  readonly trimZeros: boolean | null;
}
