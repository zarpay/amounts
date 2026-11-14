/**
 * Shared fixtures: the manifest the gem exported from
 * tests/fixtures/registry.rb, and clients built from it. Every expected
 * value in the suite is what the gem produces for that registry.
 */

import type { AmountsOptions } from "@/types.js";

import { Amounts } from "@/models/amounts.js";
import exported from "@tests/fixtures/manifest.json";

/** A fresh, mutable copy of the exported manifest. */
export function testManifest(): Record<string, unknown> {
  const json = JSON.stringify(exported);

  return JSON.parse(json) as Record<string, unknown>;
}

/** A client built from the exported manifest. */
export function testAmounts(options: AmountsOptions = {}): Amounts {
  return Amounts.fromManifest(exported, options);
}

/** A copy of the exported manifest with one value replaced at a dotted path. */
export function manifestWith(path: string, value: unknown): Record<string, unknown> {
  const manifest = testManifest();
  const keys = path.split(".");
  const last = keys.pop()!;
  const parent = keys.reduce<Record<string, unknown>>((node, key) => {
    return node[key] as Record<string, unknown>;
  }, manifest);

  parent[last] = value;

  return manifest;
}

/** The error a function throws, for asserting on its code. */
export function thrown(run: () => unknown): unknown {
  try {
    run();
  } catch (error) {
    return error;
  }

  return undefined;
}
