# Catwordle

A category-clued, Wordle-style word game. A new 5-letter word drops every 12
hours (one AM round, one PM round), with a category as a hint. Guess it in 6
tries, then share your result and see who else in your group has played.

Live at [catwordle.online](https://catwordle.online).

## How it's built

Single static HTML file (`src/index.template.html`) — no framework, no
bundler beyond the tiny build script described below.

**Puzzle bank:** the word list and categories are a hardcoded array in the
page's JS (`BANK`), deterministically shuffled with a seeded PRNG so every
visitor sees the same puzzle at the same time, with no server round-trip
needed to fetch it. This is *not* read from the Google Sheet — it only ships
with new code. If you want to edit words without redeploying, that'd mean
moving `BANK` into the Sheet and adding a `getPuzzle` API action; ask if you
want that.

**Backend (Google Sheets):** a Google Sheet + bound Apps Script Web App
(`apps-script/Code.gs`) acts as a minimal REST-ish JSON API, used only for
state:
- Per-device data (your name, stats, in-progress guesses, dismissed reveal
  banner) — scoped by a random device ID generated in `localStorage` on
  first visit, since the Sheet is one global table shared by every visitor.
- The shared leaderboard (`result-*` keys) — intentionally *not*
  device-scoped, so everyone in a round sees everyone else's result.
- A passive `DeviceLog` tab capturing non-invasive browser/device info
  (user agent, screen size, language, timezone, etc.) on each visit — no
  permission prompts, just standard `navigator`/`screen` properties.

A shared-secret token gates writes/reads to the API. It's **never** committed
to source — see below.

## Local dev

```bash
cp .env.example .env
# edit .env with your real Apps Script URL + token
node build.js
```

This writes `dist/index.html` with the placeholders in
`src/index.template.html` (`__CATWORDLE_API_URL__`, `__CATWORDLE_API_TOKEN__`)
substituted from your `.env`. Open `dist/index.html` directly, or serve it
with any static file server.

## Deployment

Netlify builds from this repo on every push:
- Build command: `node build.js` (see `netlify.toml`)
- Publish directory: `dist`
- `CATWORDLE_API_URL` and `CATWORDLE_API_TOKEN` are set in Netlify's
  **Site settings → Environment variables** (all deploy contexts, not just
  Production) — never in code.

Pushes to `main` deploy to production. Pull requests and other branches get
their own Deploy Preview URL automatically.

## Apps Script backend setup

See `apps-script/Code.gs` for the full API (`doGet`/`doPost` handling
`get`/`list`/`set`/`logDevice` actions). To (re)deploy:

1. Paste `Code.gs` into the Apps Script editor bound to your Sheet (a "KV"
   tab with columns `key | value | shared | updated_at` is required; a
   `DeviceLog` tab is auto-created on first device-log write).
2. Set the `TOKEN` script property: **Project Settings → Script Properties →
   Add script property**, key `TOKEN`, value = your shared secret. Do not
   hardcode it in the file.
3. **Deploy → New deployment → Web app**, Execute as *Me*, Who has access
   *Anyone*. Copy the `/exec` URL into `CATWORDLE_API_URL`.
4. Future code changes: **Deploy → Manage deployments → edit → New version →
   Deploy** — the `/exec` URL stays stable.
