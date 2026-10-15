# Utter website

The marketing site at https://utter.run: one static page, Cutaway Busytown. Design notes are in `DESIGN.md`.

- `public/index.html` is the page (inline CSS, JS and SVG). Fonts, screenshots, the reel and the companion robot (`public/robot/`, kept byte-identical to the app's copies by `Windows and Linux/src/companion-moments.test.js`) sit beside it.
- `npm run dev` serves `public/` at http://127.0.0.1:4173/. The waitlist form never posts from localhost.
- `npm run build` copies `public/` to `dist/`. Vercel runs it and publishes `dist/` (see `vercel.json`); only pushes to `production` deploy (`vercel-ignore.sh`).

There are no dependencies to install.
