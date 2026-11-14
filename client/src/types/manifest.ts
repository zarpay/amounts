/**
 * The manifest, as the gem writes it (`Amount.manifest`). Keys are the
 * gem's, snake_case, so the JSON reads like the Rails initializer that
 * produced it. See specs/02-manifest.md.
 */

/** A unit label: one string, or plural forms keyed by I18n plural key. */
export type Label = string | Readonly<Record<string, string>>;

/** One display unit of a type, as written by the gem. */
export interface ManifestDisplayUnit {
  scale: string;
  symbol: Label | null;
  ui_decimals: number | null;
  format: string | null;
  trim_zeros: boolean | null;
}

/** One registered type, written with the `Amount.register` option names. */
export interface ManifestType {
  decimals: number;
  display_symbol: Label;
  display_format: string;
  ui_decimals: number;
  trim_zeros: boolean;
  display_units: Record<string, ManifestDisplayUnit> | null;
  default_display: string | null;
}

/** One directional default rate, as an exact decimal string. */
export interface ManifestRate {
  from: string;
  to: string;
  rate: string;
}

/** A display unit's resolved translations in one locale. */
export interface ManifestLocaleUnit {
  label: Label | null;
  format: string | null;
}

/** A type's resolved translations in one locale. */
export interface ManifestLocaleType {
  label: Label | null;
  format: string | null;
  units: Record<string, ManifestLocaleUnit>;
}

/** Every I18n lookup the core makes, resolved for one locale. */
export interface ManifestLocale {
  number: { delimiter: string; separator: string };
  compact: { format: string; units: Record<string, Label | null> };
  types: Record<string, ManifestLocaleType>;
}

/** The whole manifest: `Amount.manifest(locales: [...])`. */
export interface AmountsManifest {
  v: 1;
  types: Record<string, ManifestType>;
  rates: ManifestRate[];
  locales: Record<string, ManifestLocale>;
}
