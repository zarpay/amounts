/**
 * The shapes callers hand to and get back from the client's public API.
 * See specs/03-interface.md.
 */

import type { Label } from "@/types/manifest.js";

/** A constructor value: `bigint` is atomic; `string` and `number` are UI values. */
export type AmountInput = bigint | number | string;

/** An exact decimal: a scalar, a rate or a count. A `number` goes through its string form. */
export type DecimalInput = bigint | number | string;

/** How `of` reads its value, overriding inference (the gem's `from:`). */
export type AmountInputFormat = "atomic" | "ui";

/** Options for `Amounts#of`. */
export interface AmountOfOptions {
  from?: AmountInputFormat;
}

/** The versioned payload of `Amount#toHash`, read back by `Amounts#load`. */
export interface AmountHash {
  v?: number | null;
  atomic: bigint | number | string;
  symbol: string;
}

/** Which way display rounding goes: down (`floor`, the default) or up. */
export type RoundingDirection = "floor" | "ceil";

/** `compact:` — `true` keeps 3 significant digits; `{ precision }` changes that. */
export type CompactOption = boolean | { precision?: number };

/** Options for `Amount#ui`. */
export interface AmountUiOptions {
  unit?: string;
  direction?: RoundingDirection;
  decorated?: boolean;
  trimZeros?: boolean | null;
  locale?: string | null;
  compact?: CompactOption;
}

/** Options for `Amount#unitLabel`. */
export interface AmountUnitLabelOptions {
  unit?: string;
  locale?: string | null;
  count?: DecimalInput;
}

/** Options for `Amount#displayFormat`. */
export interface AmountDisplayFormatOptions {
  unit?: string;
  locale?: string | null;
}

/** Options for `Amount#to`. */
export interface AmountToOptions {
  rate?: DecimalInput | null;
}

/** Options for `Amounts.fromManifest`. */
export interface AmountsOptions {
  /** The locale used when a call gives none (the gem's `Amount.localize` + `I18n.locale`). */
  locale?: string | null;
}

/** Options for `Amounts#parseUi`. */
export interface AmountsParseUiOptions {
  locale?: string | null;
}

/** A display unit of a registered type, read from the manifest. */
export interface DisplayUnit {
  readonly scale: string;
  readonly symbol: Label | null;
  readonly uiDecimals: number | null;
  readonly format: string | null;
  readonly trimZeros: boolean | null;
}
