import { errors } from "@/helpers/errors-helper.js";
import { readArray, readDecimal, readRecord, readString } from "@/helpers/manifest-helper.js";
import { Locale } from "@/models/locale.js";
import { RegistryEntry } from "@/models/registry-entry.js";

/** The manifest format this client reads (`Amount::Manifest::VERSION`). */
const MANIFEST_VERSION = 1;

/**
 * The registered types, the directional default rates and the locale
 * tables, read from the manifest — the gem's `Amount::Registry`.
 *
 * It is locked from birth: the manifest is the only way in, so there is
 * no `register` and no `register_default_rate`. Reach it through
 * {@link Amounts.registry} to ask what the server registered — to build a
 * currency picker, check a rate exists before offering a conversion, or
 * list the locales a language switcher can offer.
 *
 * @example
 *   const { registry } = amounts;
 *
 *   registry.symbols;                         // ["USDC", "USD", "SOL", ...]
 *   registry.lookup("USDC").decimals;         // 6
 *   registry.hasDefaultRate("USDC", "SOL");   // true
 *   registry.localeNames;                     // ["en", "de"]
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
   * Builds a registry from a manifest, validating all of it: the version,
   * every type and display unit, every rate (which must name registered
   * types and be a decimal string), and every locale table. A registry
   * that constructs never fails later on a missing or malformed key.
   *
   * {@link Amounts.fromManifest} calls this; use that.
   *
   * @param value - the parsed manifest
   * @throws {@link AmountError} `INVALID_MANIFEST` naming the first
   *   malformed path, such as `types.USDC.decimals` or `rates.0.rate`
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

  /**
   * Every registered symbol, in the order the gem registered them. A new
   * array on each read.
   *
   * @example A currency picker
   *   const options = amounts.registry.symbols.map((symbol) => ({
   *     value: symbol,
   *     label: amounts.of(symbol, 0n).unitLabel(),
   *   }));
   */
  get symbols(): string[] {
    return [...this.entries.keys()];
  }

  /**
   * The locales the manifest was exported with — the only ones `ui`,
   * `parseUi` and `fromManifest` accept.
   */
  get localeNames(): string[] {
    return [...this.locales.keys()];
  }

  /**
   * Whether a symbol is registered.
   *
   * @example
   *   if (!amounts.registry.registered(params.symbol)) return notFound();
   */
  registered(symbol: string): boolean {
    return this.entries.has(symbol);
  }

  /**
   * A type's registry entry: its decimals, labels, templates and display
   * units.
   *
   * @param symbol - a registered symbol
   * @throws {@link AmountError} `UNKNOWN_TYPE`
   *
   * @example
   *   amounts.registry.lookup("USDC").uiDecimals;  // 2
   */
  lookup(symbol: string): RegistryEntry {
    const entry = this.entries.get(symbol);

    if (entry === undefined) throw errors.unknownType(symbol);

    return entry;
  }

  /**
   * The default rate the server registered from one type to another, as
   * the exact decimal string the gem uses (a `Rational` rate is written to
   * its 19 significant digits, as `coerce_decimal` stores it).
   *
   * Directional: a rate from `from` to `to` says nothing about `to` to
   * `from`, and is never inverted.
   *
   * @param from - the source type
   * @param to - the target type
   * @throws {@link AmountError} `NO_DEFAULT_RATE`
   *
   * @example
   *   amounts.registry.defaultRate("USDC", "SOL");  // "0.0066666666"
   */
  defaultRate(from: string, to: string): string {
    const rate = this.rates.get(rateKey(from, to));

    if (rate === undefined) throw errors.noDefaultRate(from, to);

    return rate;
  }

  /**
   * Whether a default rate exists in this direction — whether `add`,
   * `compare` and `to` can cross from `from` to `to` without an explicit
   * rate.
   *
   * @example Only offer conversions that will work
   *   const targets = registry.symbols.filter((to) => registry.hasDefaultRate("USDC", to));
   */
  hasDefaultRate(from: string, to: string): boolean {
    return this.rates.has(rateKey(from, to));
  }

  /**
   * A locale's resolved table. {@link Amounts.localeFor} chooses which
   * locale a call uses; this only finds its table.
   *
   * @param name - a locale the manifest was exported with
   * @throws {@link AmountError} `UNKNOWN_LOCALE`
   */
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
