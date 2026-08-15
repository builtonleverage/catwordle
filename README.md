# Catwordle

A category-clued, Wordle-style word game. A new 5-letter word drops every 12
hours (one AM round, one PM round), with a category as a hint. Guess it in 6
tries, then share your result and see who else in your group has played.

Live at [catwordle.online](https://catwordle.online).

## How it's built

Single static HTML file (`src/index.template.html`) — no framework, no
bundler beyond the tiny build script described below.

**Puzzle bank:** the default word list and categories are a hardcoded array
in the page's JS (`BANK`), deterministically shuffled with a seeded PRNG so
every visitor sees the same puzzle at the same time. This is the permanent
fallback and never changes. A `round_puzzles` table (see
`supabase/002_round_puzzles.sql`) can *override* specific rounds with
auto-generated content — on boot, the page checks for a row matching the
current/previous `slot_index` and uses it if present, otherwise falls back
to `BANK`. Only the `service_role` key can write `round_puzzles` (see
below), so a scheduled generation job can keep adding fresh content
indefinitely without the game ever depending on that job actually running —
if it stops, the game keeps working off whatever's already accumulated.

**Guess validation:** guesses must be real words, checked against
`src/assets/words.json` (the standard `tabatkins/wordle-list` reference
list, ~14,855 words, fetched async on boot into a `Set`). The actual
answer is always accepted regardless of dictionary membership — some
`BANK` entries are proper nouns (country/state names) not in the list,
so this safety net keeps every round winnable. If the word list hasn't
finished loading yet, validation fails open (guess is allowed) rather
than blocking play.

**Backend (Supabase/Postgres):** see `supabase/schema.sql` (core tables) and
`supabase/002_round_puzzles.sql` (puzzle overrides) for the full schema.
Tables are queried directly from the browser via Supabase's auto-generated
REST API (PostgREST) — no custom backend code:
- `devices` — per-browser name + running stats (played/wins/streak), keyed
  by a random `device_id` generated into `localStorage` on first visit.
- `device_rounds` — per-device, per-round state: in-progress/finished
  guesses, and whether the reveal banner's been dismissed.
- `results` — the shared leaderboard, one row per (round, player name).
  Intentionally *not* device-scoped, so everyone in a round sees everyone
  else's result. `solve_ms` (see `supabase/005_solve_time.sql`) is each
  player's own elapsed time from their first guess to their winning
  guess, used to break ties fairly — the old behavior (breaking ties by
  absolute finish timestamp) favored whoever opened the app earliest in
  the round, not whoever actually solved it fastest once they engaged.
- `device_log` — passive browser/device info (user agent, screen size,
  language, timezone, etc.) upserted on each visit — no permission
  prompts, just standard `navigator`/`screen` properties.
- `round_puzzles` — auto-generated puzzle overrides, keyed by `slot_index`.
  Publicly readable, but only writable with the `service_role` key (not the
  public anon key) since it controls the actual game content shown to
  every visitor — a scheduled job holds that key, the frontend never does.

`medal_tally` (a view, not a table — see `supabase/004_medal_tally.sql`)
computes all-time gold/silver/bronze medal counts per player live from
`results`, using the same ranking rule as the per-round badges (fewest
guesses, ties broken by earliest finish). No sync job or cache to keep
up to date — it just reflects whatever's in `results` at query time.

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
   → Run. This creates the core four tables and their RLS policies.
3. Repeat for `supabase/002_round_puzzles.sql` (and any later-numbered
   migration files) — run each once, in order.
4. **Project Settings → API** → copy the **Project URL** and the **`anon`
   `public`** key into `CATWORDLE_SUPABASE_URL` / `CATWORDLE_SUPABASE_ANON_KEY`.
   The **`service_role`** key (same page) is only needed for the scheduled
   puzzle-generation job — never put it in `.env` or anywhere client-side.
5. No further deploy step needed — PostgREST picks up schema changes
   immediately. Future schema changes: write a new numbered `.sql`
   migration, run it in the SQL Editor.
