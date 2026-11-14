import type { Label } from "@/types.js";

import {
  readLabel,
  readNullable,
  readRecord,
  readString,
  readTemplate,
} from "@/helpers/manifest-helper.js";
import { Ratio } from "@/models/ratio.js";

/** A type's translations: its label and format, and each display unit's. */
interface LocaleTypeTable {
  label: Label | null;
  format: string | null;
  units: Map<string, { label: Label | null; format: string | null }>;
}

/**
 * One locale's table from the manifest, and the number and plural rules
 * the gem's `Amount::Locale` applies with it.
 *
 * The gem resolved every I18n lookup before writing the table, so each
 * reader here returns the translation or `null`; the fallbacks (to
 * `display_symbol`, to the registered template) stay with the caller,
 * which applies them in the gem's order.
 */
export class Locale {
  readonly name: string;
  readonly delimiter: string;
  readonly separator: string;
  /** The template joining a compacted number and its scale word. */
  readonly compactFormat: string;

  private readonly compactUnits: Map<string, Label | null>;
  private readonly types: Map<string, LocaleTypeTable>;

  private constructor(
    name: string,
    number: { delimiter: string; separator: string },
    compactFormat: string,
    compactUnits: Map<string, Label | null>,
    types: Map<string, LocaleTypeTable>,
  ) {
    this.name = name;
    this.delimiter = number.delimiter;
    this.separator = number.separator;
    this.compactFormat = compactFormat;
    this.compactUnits = compactUnits;
    this.types = types;
    Object.freeze(this);
  }

  /**
   * Builds a locale from its manifest table.
   *
   * @throws AmountError INVALID_MANIFEST naming the first malformed path
   */
  static fromManifest(name: string, value: unknown, path: string): Locale {
    const table = readRecord(value, path);
    const number = readRecord(table["number"], `${path}.number`);
    const compact = readRecord(table["compact"], `${path}.compact`);
    const delimiter = readString(number["delimiter"], `${path}.number.delimiter`);
    const separator = readString(number["separator"], `${path}.number.separator`);
    const compactFormat = readTemplate(compact["format"], `${path}.compact.format`);
    const compactUnits = readCompactUnits(compact["units"], `${path}.compact.units`);
    const types = readTypes(table["types"], `${path}.types`);

    return new Locale(name, { delimiter, separator }, compactFormat, compactUnits, types);
  }

  /**
   * Picks a label's form without a locale, as the gem does without I18n:
   * `one` when the count is exactly 1 and the form exists, else `other`.
   * A string passes through.
   */
  static plain(label: Label, count: Ratio | null): string | null {
    if (typeof label === "string") return label;

    const isOne = count?.equals(ONE) ?? false;
    const one = label["one"];

    if (isOne && one !== undefined) return one;

    return label["other"] ?? null;
  }

  /**
   * Picks a label's form in a locale, by I18n's default plural rule:
   * `zero` when the count is 0 and the form exists, `one` when it is 1,
   * else `other` — and `other` whenever the chosen form is missing, or
   * there is no count at all.
   */
  static pluralize(label: Label, count: Ratio | null): string | null {
    if (typeof label === "string") return label;

    if (count === null) return label["other"] ?? null;

    const key = pluralKey(label, count);

    return label[key] ?? label["other"] ?? null;
  }

  /** The translation of a scale word (`thousand`, `million`, ...), or `null`. */
  compactUnit(scale: string): Label | null {
    return this.compactUnits.get(scale) ?? null;
  }

  /** The translation of a type's label, or `null`. */
  typeLabel(symbol: string): Label | null {
    return this.types.get(symbol)?.label ?? null;
  }

  /** The locale's template for a type, or `null`. */
  typeFormat(symbol: string): string | null {
    return this.types.get(symbol)?.format ?? null;
  }

  /** The translation of a display unit's label, or `null`. */
  unitLabel(symbol: string, unit: string): Label | null {
    return this.types.get(symbol)?.units.get(unit)?.label ?? null;
  }

  /** The locale's template for a display unit, or `null`. */
  unitFormat(symbol: string, unit: string): string | null {
    return this.types.get(symbol)?.units.get(unit)?.format ?? null;
  }

  /**
   * Rewrites a plain number (`"-1234.50"`) with the locale's delimiter and
   * separator (`"-1.234,50"`). The gem's `Locale.apply`.
   */
  applyNumber(plain: string): string {
    const negative = plain.startsWith("-");
    const unsigned = negative ? plain.slice(1) : plain;
    const [whole = "", fraction] = unsigned.split(".", 2);
    const grouped = groupThousands(whole, this.delimiter);
    const sign = negative ? "-" : "";
    const decimals = fraction === undefined ? "" : `${this.separator}${fraction}`;

    return `${sign}${grouped}${decimals}`;
  }
}

const ONE = Ratio.of(1n);

function pluralKey(label: Readonly<Record<string, string>>, count: Ratio): string {
  if (count.isZero() && label["zero"] !== undefined) return "zero";

  return count.equals(ONE) ? "one" : "other";
}

function groupThousands(digits: string, delimiter: string): string {
  const groups: string[] = [];

  for (let end = digits.length; end > 0; end -= 3) {
    const start = Math.max(end - 3, 0);

    groups.unshift(digits.slice(start, end));
  }

  return groups.join(delimiter);
}

function readCompactUnits(value: unknown, path: string): Map<string, Label | null> {
  const units = readRecord(value, path);
  const entries = Object.entries(units).map(([scale, label]) => {
    const read = readNullable(label, `${path}.${scale}`, readLabel);

    return [scale, read] as const;
  });

  return new Map(entries);
}

function readTypes(value: unknown, path: string): Map<string, LocaleTypeTable> {
  const types = readRecord(value, path);
  const entries = Object.entries(types).map(([symbol, table]) => {
    const read = readType(table, `${path}.${symbol}`);

    return [symbol, read] as const;
  });

  return new Map(entries);
}

function readType(value: unknown, path: string): LocaleTypeTable {
  const table = readRecord(value, path);
  const label = readNullable(table["label"], `${path}.label`, readLabel);
  const format = readNullable(table["format"], `${path}.format`, readTemplate);
  const units = readUnits(table["units"], `${path}.units`);

  return { label, format, units };
}

function readUnits(
  value: unknown,
  path: string,
): Map<string, { label: Label | null; format: string | null }> {
  const units = readRecord(value, path);
  const entries = Object.entries(units).map(([unit, table]) => {
    const unitPath = `${path}.${unit}`;
    const unitTable = readRecord(table, unitPath);
    const label = readNullable(unitTable["label"], `${unitPath}.label`, readLabel);
    const format = readNullable(unitTable["format"], `${unitPath}.format`, readTemplate);

    return [unit, { label, format }] as const;
  });

  return new Map(entries);
}
