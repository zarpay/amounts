import { errors } from "@/helpers/errors-helper.js";
import { readArray, readDecimal, readRecord, readString } from "@/helpers/manifest-helper.js";
import { Locale } from "@/models/locale.js";
import { RegistryEntry } from "@/models/registry-entry.js";

const MANIFEST_VERSION = 1;

/**
 * The registered types, default rates and locale tables, read from the
 * manifest. The gem's `Amount::Registry`, locked from birth: the manifest
 * is the only way in.
 */
export class Registry {
  private readonly entries: Map<string, RegistryEntry>;
  private readonly rates: Map<string, string>;
  private readonly locales: Map<string, Locale>;

  private constructor(
    entries: Map<string, RegistryEntry>,
    rates: Map<string, string>,
    locales: Map<string, Locale>,
  ) {
    this.entries = entries;
    this.rates = rates;
    this.locales = locales;
    Object.freeze(this);
  }

  /**
   * Builds a registry from a manifest, validating all of it: a registry
   * that constructs never fails later on a missing or malformed key.
   *
   * @throws AmountError INVALID_MANIFEST naming the first malformed path
   */
  static fromManifest(value: unknown): Registry {
    const manifest = readRecord(value, "manifest");

    if (manifest["v"] !== MANIFEST_VERSION) {
      throw errors.invalidManifest("v", String(MANIFEST_VERSION));
    }

    const entries = readEntries(manifest["types"]);
    const rates = readRates(manifest["rates"], entries);
    const locales = readLocales(manifest["locales"]);

    return new Registry(entries, rates, locales);
  }

  /** Registered symbols, in the order the gem registered them. */
  get symbols(): string[] {
    return [...this.entries.keys()];
  }

  /** The locales the manifest has tables for. */
  get localeNames(): string[] {
    return [...this.locales.keys()];
  }

  registered(symbol: string): boolean {
    return this.entries.has(symbol);
  }

  /** @throws AmountError UNKNOWN_TYPE */
  lookup(symbol: string): RegistryEntry {
    const entry = this.entries.get(symbol);

    if (entry === undefined) throw errors.unknownType(symbol);

    return entry;
  }

  /**
   * The directional default rate, as an exact decimal string.
   *
   * @throws AmountError NO_DEFAULT_RATE
   */
  defaultRate(from: string, to: string): string {
    const rate = this.rates.get(rateKey(from, to));

    if (rate === undefined) throw errors.noDefaultRate(from, to);

    return rate;
  }

  hasDefaultRate(from: string, to: string): boolean {
    return this.rates.has(rateKey(from, to));
  }

  /** @throws AmountError UNKNOWN_LOCALE */
  locale(name: string): Locale {
    const locale = this.locales.get(name);

    if (locale === undefined) throw errors.unknownLocale(name);

    return locale;
  }
}

/**
 * The private map key for a rate. Never parsed back: the two symbols are
 * only ever looked up together.
 */
function rateKey(from: string, to: string): string {
  return JSON.stringify([from, to]);
}

function readEntries(value: unknown): Map<string, RegistryEntry> {
  const types = readRecord(value, "types");
  const entries = Object.entries(types).map(([symbol, type]) => {
    const entry = RegistryEntry.fromManifest(symbol, type, `types.${symbol}`);

    return [symbol, entry] as const;
  });

  return new Map(entries);
}

function readRates(value: unknown, entries: Map<string, RegistryEntry>): Map<string, string> {
  const rows = readArray(value, "rates");
  const rates = rows.map((row, index) => readRate(row, `rates.${index}`, entries));

  return new Map(rates);
}

function readRate(
  value: unknown,
  path: string,
  entries: Map<string, RegistryEntry>,
): readonly [string, string] {
  const row = readRecord(value, path);
  const from = readSymbol(row["from"], `${path}.from`, entries);
  const to = readSymbol(row["to"], `${path}.to`, entries);
  const rate = readDecimal(row["rate"], `${path}.rate`);

  return [rateKey(from, to), rate];
}

function readSymbol(value: unknown, path: string, entries: Map<string, RegistryEntry>): string {
  const symbol = readString(value, path);

  if (!entries.has(symbol)) throw errors.invalidManifest(path, "a registered symbol");

  return symbol;
}

function readLocales(value: unknown): Map<string, Locale> {
  const tables = readRecord(value, "locales");
  const locales = Object.entries(tables).map(([name, table]) => {
    const locale = Locale.fromManifest(name, table, `locales.${name}`);

    return [name, locale] as const;
  });

  return new Map(locales);
}
