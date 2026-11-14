import type { DisplayUnit, Label } from "@/types.js";

import { errors } from "@/helpers/errors-helper.js";
import {
  readBoolean,
  readCount,
  readDecimal,
  readDisplaySymbol,
  readLabel,
  readNullable,
  readRecord,
  readString,
  readTemplate,
} from "@/helpers/manifest-helper.js";

/**
 * One registered type — the gem's `Registry::Entry`, read from the
 * manifest. Each field is the `Amount.register` option of the same name,
 * camelCased, as the server registered it.
 *
 * Read it through {@link Registry.lookup} or {@link Amount.registryEntry}
 * when you need a type's configuration directly: the decimals a form
 * input should allow, the label for a column header, the display units to
 * offer in a toggle.
 *
 * @example An input that allows exactly the type's decimals
 *   const { decimals, uiDecimals } = amounts.registry.lookup("USDC");
 *   <input inputMode="decimal" step={`1e-${decimals}`} />
 *
 * @example A unit toggle
 *   const units = Object.keys(amounts.registry.lookup("GOLD").displayUnits ?? {});
 *   // ["oz_t", "gram", "kg", "grain"]
 */
export class RegistryEntry {
  /** The symbol the type was registered under (`"USDC"`). */
  readonly symbol: string;
  /** Storage decimals: one whole unit is `10 ** decimals` atomic units. */
  readonly decimals: number;
  /**
   * The unit label `ui` places: a string (`"$"`), or plural forms
   * (`{ one: "search", other: "searches" }`) that always include `other`.
   */
  readonly displaySymbol: Label;
  /**
   * The template decorated `ui` output uses: `%n` is the number and `%u`
   * the label. The gem resolved `display_position` into it (`:prefix` is
   * `"%u%n"`, `:suffix` is `"%n %u"`).
   */
  readonly displayFormat: string;
  /** Decimals `ui` shows by default. */
  readonly uiDecimals: number;
  /** Whether `ui` strips trailing zeros by default (`"2.5 SOL"`, not `"2.5000 SOL"`). */
  readonly trimZeros: boolean;
  /**
   * The type's display units by key, or `null` when it has none. A display
   * unit changes how an amount is shown (troy ounces as grams), never its
   * type.
   */
  readonly displayUnits: Readonly<Record<string, DisplayUnit>> | null;
  /**
   * The registered `default_display` unit key. Stored as the gem stores
   * it; nothing in the gem's core or the client reads it, so `ui` never
   * picks a unit unless you pass one.
   */
  readonly defaultDisplay: string | null;

  private constructor(fields: Omit<RegistryEntry, "displayUnit">) {
    this.symbol = fields.symbol;
    this.decimals = fields.decimals;
    this.displaySymbol = fields.displaySymbol;
    this.displayFormat = fields.displayFormat;
    this.uiDecimals = fields.uiDecimals;
    this.trimZeros = fields.trimZeros;
    this.displayUnits = fields.displayUnits;
    this.defaultDisplay = fields.defaultDisplay;
    Object.freeze(this);
  }

  /**
   * Builds an entry from its type in the manifest, validating every field.
   * {@link Registry.fromManifest} calls this for each type.
   *
   * @param symbol - the key the type was found under
   * @param value - the type's manifest object
   * @param path - where it was found, for error messages (`types.USDC`)
   * @throws {@link AmountError} `INVALID_MANIFEST` naming the first malformed path
   */
  static fromManifest(symbol: string, value: unknown, path: string): RegistryEntry {
    const type = readRecord(value, path);

    return new RegistryEntry({
      symbol,
      decimals: readCount(type["decimals"], `${path}.decimals`),
      displaySymbol: readDisplaySymbol(type["display_symbol"], `${path}.display_symbol`),
      displayFormat: readTemplate(type["display_format"], `${path}.display_format`),
      uiDecimals: readCount(type["ui_decimals"], `${path}.ui_decimals`),
      trimZeros: readBoolean(type["trim_zeros"], `${path}.trim_zeros`),
      displayUnits: readNullable(type["display_units"], `${path}.display_units`, readDisplayUnits),
      defaultDisplay: readNullable(type["default_display"], `${path}.default_display`, readString),
    });
  }

  /**
   * A display unit's spec — the gem's `Entry#display_unit`.
   *
   * @param unit - the unit's key
   * @returns its scale, symbol, decimals, template and trim setting
   * @throws {@link AmountError} `INVALID_DISPLAY_UNIT` when the type has no
   *   display units, or not this one
   *
   * @example
   *   amounts.registry.lookup("GOLD").displayUnit("gram").scale;  // "31.1034768"
   */
  displayUnit(unit: string): DisplayUnit {
    if (this.displayUnits === null) throw errors.noDisplayUnits(this.symbol);

    const spec = this.displayUnits[unit];

    if (spec === undefined) throw errors.unknownDisplayUnit(unit, this.symbol);

    return spec;
  }
}

function readDisplayUnits(value: unknown, path: string): Readonly<Record<string, DisplayUnit>> {
  const units = readRecord(value, path);
  const entries = Object.entries(units).map(([unit, spec]) => {
    const read = readDisplayUnit(spec, `${path}.${unit}`);

    return [unit, read] as const;
  });

  return Object.freeze(Object.fromEntries(entries));
}

function readDisplayUnit(value: unknown, path: string): DisplayUnit {
  const spec = readRecord(value, path);

  return Object.freeze({
    scale: readDecimal(spec["scale"], `${path}.scale`),
    symbol: readNullable(spec["symbol"], `${path}.symbol`, readLabel),
    uiDecimals: readNullable(spec["ui_decimals"], `${path}.ui_decimals`, readCount),
    format: readNullable(spec["format"], `${path}.format`, readTemplate),
    trimZeros: readNullable(spec["trim_zeros"], `${path}.trim_zeros`, readBoolean),
  });
}
