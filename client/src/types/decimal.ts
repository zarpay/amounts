/**
 * Internal vocabulary between the decimal helper and `Ratio`. Not part of
 * the public API.
 */

/** A decimal as an integer and a power of ten: `coefficient / 10 ** scale`. */
export interface ScaledDecimal {
  coefficient: bigint;
  scale: number;
}
