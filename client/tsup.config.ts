import { defineConfig } from "tsup";

/**
 * One entry, two module formats, declarations for each: ESM for bundlers
 * and modern Node, CommonJS for older toolchains and Metro configurations
 * that don't read `exports`. ES2020 is the floor because amounts are
 * `bigint`s.
 */
export default defineConfig({
  entry: ["src/index.ts"],
  format: ["esm", "cjs"],
  target: "es2020",
  dts: true,
  clean: true,
  sourcemap: true,
});
