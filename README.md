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
needed to fetch it. This is *not* read from the database — it only ships
with new code. If you want to edit words without redeploying, that'd mean a
`puzzles` table and a query for the current slot; ask if you want that.

**Backend (Supabase/Postgres):** see `supabase/schema.sql` for the full
schema. Four tables, queried directly from the browser via Supabase's
auto-generated REST API (PostgREST) — no custom backend code:
- `devices` — per-browser name + running stats (played/wins/streak), keyed
  by a random `device_id` generated into `localStorage` on first visit.
- `device_rounds` — per-device, per-round state: in-progress/finished
  guesses, and whether the reveal banner's been dismissed.
- `results` — the shared leaderboard, one row per (round, player name).
  Intentionally *not* device-scoped, so everyone in a round sees everyone
  else's result. Queried with `order=won.desc,guesses.asc` so sorting
  happens in Postgres, not client-side.
- `device_log` — passive browser/device info (user agent, screen size,
  language, timezone, etc.) upserted on each visit — no permission
  prompts, just standard `navigator`/`screen` properties.

Access control is via Postgres Row Level Security policies (in
`schema.sql`), not by hiding a secret — the Supabase anon key is meant to
be public and is safe to ship in the built page.

This replaced an earlier Google Sheets + Apps Script backend. That worked
but had a hard latency floor (~2-2.5s per Apps Script call, regardless of
how much the requests were batched) — Postgres queries are typically
50-300ms.

## Local dev

```bash
cp .env.example .env
# edit .env with your real Supabase project URL + anon key
node build.js
```

This writes `dist/index.html` with the placeholders in
`src/index.template.html` (`__CATWORDLE_SUPABASE_URL__`,
`__CATWORDLE_SUPABASE_ANON_KEY__`) substituted from your `.env`. Open
`dist/index.html` directly, or serve it with any static file server.

## Deployment

Netlify builds from this repo on every push:
- Build command: `node build.js` (see `netlify.toml`)
- Publish directory: `dist`
- `CATWORDLE_SUPABASE_URL` and `CATWORDLE_SUPABASE_ANON_KEY` are set in
  Netlify's **Site settings → Environment variables** (all deploy contexts,
  not just Production) — never in code.

Pushes to `main` deploy to production. Pull requests and other branches get
their own Deploy Preview URL automatically.

## Supabase backend setup

1. Create a project at [supabase.com](https://supabase.com).
2. **SQL Editor → New query** → paste the contents of `supabase/schema.sql`
   → Run. This creates all four tables and their RLS policies.
3. **Project Settings → API** → copy the **Project URL** and the **`anon`
   `public`** key into `CATWORDLE_SUPABASE_URL` / `CATWORDLE_SUPABASE_ANON_KEY`.
4. No further deploy step needed — PostgREST picks up schema changes
   immediately. Future schema changes: write a new `.sql` migration, run it
   in the SQL Editor.
