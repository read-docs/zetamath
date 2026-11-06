# Zetamath

A local-first mental arithmetic trainer. Type the correct answer and the next problem appears.

| Folder | What | Stack |
|---|---|---|
| [`web/`](web/) | Desktop-first web app | Vite, React, TypeScript, Zustand |
| [`mobile/`](mobile/) | Android app for the Galaxy A54 | Flutter via fvm |
| [`shared/fixtures/`](shared/fixtures/) | Engine test fixtures both apps check against | JSON |

Each app is self-contained, so run commands from its own folder:

```sh
cd web && npm install && npm run dev
cd mobile && fvm flutter pub get && fvm flutter run
```

Both apps generate the same problems for the same seed and read the same history export format, so results can move between them.
