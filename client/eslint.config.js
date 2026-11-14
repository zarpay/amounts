import eslint from "@eslint/js";
import stylistic from "@stylistic/eslint-plugin";
import prettier from "eslint-config-prettier";
import importX from "eslint-plugin-import-x";
import perfectionist from "eslint-plugin-perfectionist";
import tseslint from "typescript-eslint";

/**
 * ESLint configuration.
 *
 * Layers, in order of application:
 * 1. eslint recommended — baseline JavaScript correctness rules
 * 2. typescript-eslint recommendedTypeChecked — type-aware safety rules
 * 3. typescript-eslint stylisticTypeChecked — conventional idiom rules
 * 4. Project rule overrides (documented inline below)
 * 5. eslint-config-prettier — disables any rule that would fight Prettier
 */
export default tseslint.config(
  {
    ignores: ["dist/**", "node_modules/**", "*.config.ts", "*.config.js"],
  },
  eslint.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked,
  ...tseslint.configs.stylisticTypeChecked,
  {
    plugins: {
      "@stylistic": stylistic,
      "import-x": importX,
      perfectionist,
    },
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      // Always use === / !==; loose equality hides coercion bugs.
      eqeqeq: ["error", "always"],
      // A ternary inside a ternary is unreadable; use if/else or a
      // small helper instead.
      "no-nested-ternary": "error",
      // Braces required whenever a statement spans multiple lines;
      // single-line guards like `if (x) return;` stay legal.
      curly: ["error", "multi-line"],
      // Type-only imports use top-level `import type` statements, so the
      // import groups below can separate types from values.
      "@typescript-eslint/consistent-type-imports": [
        "error",
        { prefer: "type-imports", fixStyle: "separate-type-imports" },
      ],
      "import-x/consistent-type-specifier-style": ["error", "prefer-top-level"],
      // Underscore-prefixed names are the "intentionally unused" marker.
      "@typescript-eslint/no-unused-vars": [
        "error",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
      ],
      // Bracket access is the convention for index-signature lookups
      // (manifest["types"]); dot access stays enforced for declared
      // properties.
      "@typescript-eslint/dot-notation": [
        "error",
        { allowIndexSignaturePropertyAccess: true, allowPrivateClassPropertyAccess: true },
      ],
      // Imports are grouped: third-party types, internal types,
      // third-party values, internal values — blank line between
      // groups, alphabetical within them. Autofixable.
      "perfectionist/sort-imports": [
        "error",
        {
          type: "natural",
          newlinesBetween: 1,
          internalPattern: ["^@/", "^@tests/"],
          groups: [
            ["type-builtin", "type-external"],
            ["type-internal", "type-tsconfig-path"],
            ["builtin", "external"],
            ["internal", "tsconfig-path"],
            ["type-parent", "type-sibling", "type-index", "parent", "sibling", "index"],
            "unknown",
          ],
        },
      ],
      // Conditionals breathe: a blank line before and after every if
      // and switch — except at the start or end of a block.
      "@stylistic/padding-line-between-statements": [
        "error",
        { blankLine: "always", prev: "*", next: ["if", "switch"] },
        { blankLine: "always", prev: ["if", "switch"], next: "*" },
      ],
    },
  },
  {
    // Imports always use path aliases (@/, @tests/), never relative paths.
    files: ["src/**/*.ts", "tests/**/*.ts"],
    rules: {
      "no-restricted-imports": [
        "error",
        {
          patterns: [
            {
              group: ["./*", "../*"],
              message: "Use the @/ (src) or @tests/ path aliases instead of relative imports.",
            },
          ],
        },
      ],
    },
  },
  {
    // Layers flow one way: helpers -> models. A helper never imports a
    // model, so the arithmetic and string primitives stay reusable by
    // every model.
    files: ["src/helpers/**/*.ts"],
    rules: {
      "no-restricted-imports": [
        "error",
        {
          patterns: [
            {
              group: ["./*", "../*"],
              message: "Use the @/ path alias instead of relative imports.",
            },
            {
              group: ["@/models/*"],
              message: "A helper sits below the models and never imports one.",
            },
          ],
        },
      ],
    },
  },
  {
    // The shared type vocabulary lives in src/types/ (barreled through
    // src/types.ts). A type only one module speaks is declared IN that
    // module, unexported — so an exported declaration anywhere else is a
    // type that belongs in the barrel.
    files: ["src/**/*.ts"],
    ignores: ["src/types.ts", "src/types/**", "src/helpers/errors-helper.ts"],
    rules: {
      "no-restricted-syntax": [
        "error",
        {
          selector: "ExportNamedDeclaration > TSInterfaceDeclaration",
          message:
            "A shared interface lives in src/types/ (the barrel). A module-local interface stays unexported.",
        },
        {
          selector: "ExportNamedDeclaration > TSTypeAliasDeclaration",
          message:
            "A shared type alias lives in src/types/ (the barrel). A module-local alias stays unexported.",
        },
      ],
    },
  },
  {
    // The library runs in browsers and React Native: no console output.
    files: ["src/**/*.ts"],
    rules: {
      "no-console": "error",
    },
  },
  {
    // The config file itself is plain JS and outside the tsconfig project.
    files: ["eslint.config.js"],
    extends: [tseslint.configs.disableTypeChecked],
  },
  prettier,
);
