// Copyright (c) 2026 James Maes (KofTwentyTwo)
// SPDX-License-Identifier: MIT

import js from "@eslint/js";
import stylistic from "@stylistic/eslint-plugin";

// JavaScript-only repository tools use the shared K22-CODE-TS layout and lint
// rules. TypeScript type checking does not apply to these CommonJS scripts.
export default [
   { ignores: ["artifacts/**", "node_modules/**"] },
   js.configs.recommended,
   {
      files: [".github/scripts/*.cjs", "eslint.config.mjs"],
      plugins: { "@stylistic": stylistic },
      rules: {
         "@stylistic/indent": ["error", 3, { SwitchCase: 1 }],
         "@stylistic/brace-style": ["error", "allman", { allowSingleLine: false }],
         "@stylistic/keyword-spacing": ["error", {
            before: true,
            after: true,
            overrides: {
               if: { after: false },
               for: { after: false },
               while: { after: false },
               switch: { after: false },
               catch: { after: false },
            },
         }],
         "@stylistic/no-multiple-empty-lines": ["error", { max: 3, maxBOF: 0, maxEOF: 0 }],
         "@stylistic/lines-between-class-members": ["error", "always", { exceptAfterSingleLine: true }],
         "@stylistic/semi": ["error", "always"],
         "@stylistic/quotes": ["error", "double", { avoidEscape: true }],
         "@stylistic/comma-dangle": ["error", "always-multiline"],
         "@stylistic/eol-last": ["error", "always"],
         "@stylistic/no-tabs": "error",
         "@stylistic/no-trailing-spaces": "error",
         "@stylistic/operator-linebreak": ["error", "before"],
         "@stylistic/dot-location": ["error", "property"],
         curly: ["error", "all"],
         eqeqeq: ["error", "always"],
         "no-console": "error",
         "no-warning-comments": ["error", { terms: ["todo", "fixme"], location: "start" }],
         camelcase: ["error", { properties: "never" }],
      },
   },
   {
      files: [".github/scripts/*.cjs"],
      languageOptions: {
         sourceType: "commonjs",
         globals: { require: "readonly", module: "readonly" },
      },
   },
];
