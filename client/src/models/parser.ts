import { errors } from "@/helpers/errors-helper.js";

const SUPPORTED_VERSION = "v1";
const VERSION_PREFIX = /^(v\d+):(.*)$/;

/**
 * Reads the compact string `Amount#toJSON` and the gem's `as_json` write:
 * `"USDC|1.50"`, or the versioned `"v1:USDC|1.50"`. The gem's
 * `Amount::Parser`.
 *
 * It splits the string and nothing more; the value is read as a UI value
 * by `Amounts#parse`, exactly as the gem hands it to `Amount.new`.
 */
export class Parser {
  readonly symbol: string;
  readonly value: string;

  private constructor(symbol: string, value: string) {
    this.symbol = symbol;
    this.value = value;
    Object.freeze(this);
  }

  /** @throws AmountError INVALID_INPUT unless both a symbol and a value are present */
  static parse(input: string): Parser {
    const compact = String(input);
    const body = unversioned(compact, input);
    const separator = body.indexOf("|");
    const symbol = separator === -1 ? body : body.slice(0, separator);
    const value = separator === -1 ? "" : body.slice(separator + 1);

    if (symbol === "" || value === "") throw errors.cannotParse(input);

    return new Parser(symbol, value);
  }
}

function unversioned(compact: string, input: string): string {
  const versioned = VERSION_PREFIX.exec(compact);

  if (!versioned) return compact;

  const [, version, body = ""] = versioned;

  if (version !== SUPPORTED_VERSION) throw errors.cannotParse(input);

  return body;
}
