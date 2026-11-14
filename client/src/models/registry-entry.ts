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
 * One registered type: the gem's `Registry::Entry`, read from the
 * manifest. Fields are the entry's, camelCased.
 */
export class RegistryEntry {
  readonly symbol: string;
  /** Storage decimals: atomic units per whole unit are `10 ** decimals`. */
  readonly decimals: number;
  readonly displaySymbol: Label;
  /** The template decorated `ui` output uses (`%n` number, `%u` label). */
  readonly displayFormat: string;
  readonly uiDecimals: number;
  readonly trimZeros: boolean;
  readonly displayUnits: Readonly<Record<string, DisplayUnit>> | null;
  /** Stored as the gem stores it; nothing in the core reads it. */
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
   * Builds an entry from its manifest type.
   *
   * @throws AmountError INVALID_MANIFEST naming the first malformed path
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
   * A display unit's spec.
   *
   * @throws AmountError INVALID_DISPLAY_UNIT when the type has no such unit
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
