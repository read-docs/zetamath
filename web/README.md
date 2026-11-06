# Zetamath

A local-first arithmetic trainer built with React, TypeScript, Vite, Tailwind, Zustand and Recharts.

## Run

```sh
npm install
npm run dev
```

`npm test` runs the engine and persistence tests. `npm run build` type-checks and creates `dist/`; `npm run preview` serves that build.

Type the correct answer to advance automatically. Alt+Enter restarts; Escape opens quick settings. Time, count, endless and custom tests support weighted arithmetic operations and configurable operand ranges. Add `?seed=your-seed` for repeatable problems with the same settings. A configuration containing only one possible problem cannot avoid repetition and ends with an explanatory message.

Results and full solve logs stay in IndexedDB. Settings stay in localStorage. History supports JSON backup and import. Clearing browser data removes local records. Fonts load from Google Fonts with a monospace fallback.

For optional Cloudflare Pages deployment, use `npm run build` and output directory `dist`. No backend or credentials are needed for local use.

The web-only Learn page at `/learn` offers twelve mental-arithmetic techniques with worked examples, revealable practice solutions, and links to educational sources. Open it with the book icon in the header.
