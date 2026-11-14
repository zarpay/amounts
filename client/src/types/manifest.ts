/**
 * The manifest, as the gem writes it with `Amount.manifest`. Keys are the
 * gem's, snake_case, so the JSON reads like the Rails initializer that
 * produced it. See specs/02-manifest.md for the full contract.
 *
 * {@link Amounts.fromManifest} takes the manifest as `unknown` and
 * validates it, so these types are for code that builds, stores or tests a
 * manifest — not something the client needs you to assert.
 */

/**
 * A unit label: one string (`"$"`), or plural forms keyed by I18n plural
 * key (`{ one: "search", other: "searches" }`).
 */
export type Label = string | Readonly<Record<string, string>>;

/** One display unit of a type, as the gem writes it. */
export interface ManifestDisplayUnit {
  /** The unit's scale as an exact decimal string (`coerce_decimal(scale).to_s("F")`). */
  scale: string;
  /** The unit's `:symbol`, or `null` to use the type's `display_symbol`. */
  symbol: Label | null;
  /** The unit's `:ui_decimals`, or `null` for the type's. */
  ui_decimals: number | null;
  /** The unit's `:format`, else the template its `:position` stands for, else `null`. */
  format: string | null;
  /** The unit's `:trim_zeros`, or `null` when it doesn't set one. */
  trim_zeros: boolean | null;
}

/** One registered type, written with the `Amount.register` option names. */
export interface ManifestType {
  /** Storage decimals. */
  decimals: number;
  /** The unit label: a string, or plural forms that include `other`. */
  display_symbol: Label;
  /** The resolved template (`display_position` already turned into one). */
  display_format: string;
  /** Default display decimals. */
  ui_decimals: number;
  /** Whether display strips trailing zeros by default. */
  trim_zeros: boolean;
  /** The display units by key, or `null`. */
  display_units: Record<string, ManifestDisplayUnit> | null;
  /** The `default_display` unit key, or `null`. Stored only. */
  default_display: string | null;
}

/** One directional default rate: one `from` is worth `rate` of `to`. */
export interface ManifestRate {
  /** The source type. */
  from: string;
  /** The target type. */
  to: string;
  /** The rate as an exact decimal string (`BigDecimal#to_s("F")`). */
  rate: string;
}

/** A display unit's resolved translations in one locale. */
export interface ManifestLocaleUnit {
  /** The unit's translated label, raw, or `null`. */
  label: Label | null;
  /** The unit's translated template, or `null`. */
  format: string | null;
}

/** A type's resolved translations in one locale. */
export interface ManifestLocaleType {
  /** The type's translated label (its `label_key`, else `amounts.units.<sym>`), raw, or `null`. */
  label: Label | null;
  /** The type's translated template (`amounts.formats.<sym>`), or `null`. */
  format: string | null;
  /** Each display unit's translations, by unit key. */
  units: Record<string, ManifestLocaleUnit>;
}

/** Every I18n lookup the core makes, resolved for one locale. */
export interface ManifestLocale {
  /** `number.format`'s delimiter and separator, with the gem's defaults. */
  number: { delimiter: string; separator: string };
  /** `number.human.decimal_units`: the compact format and each scale's word, or `null`. */
  compact: { format: string; units: Record<string, Label | null> };
  /** Each type's translations, by symbol. */
  types: Record<string, ManifestLocaleType>;
}

/**
 * The whole manifest: the output of `Amount.manifest(locales: [...])`.
 *
 * @example Writing one to a file at build time (Ruby)
 *   File.write("app/javascript/amounts.json", Amount.manifest(locales: %i[en de]).to_json)
 */
export interface AmountsManifest {
  /** The manifest format version. */
  v: 1;
  /** Every registered type, by symbol, in registration order. */
  types: Record<string, ManifestType>;
  /** Every registered default rate. */
  rates: ManifestRate[];
  /** One table per exported locale, by name; `{}` when none were asked for. */
  locales: Record<string, ManifestLocale>;
}
