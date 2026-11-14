import { resolve } from "node:path";
import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: {
    alias: {
      "@": resolve(import.meta.dirname, "src"),
      "@tests": resolve(import.meta.dirname, "tests"),
    },
  },
  test: {
    globals: false,
  },
});
