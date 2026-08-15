-- Catwordle Supabase schema.
-- Run this once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
--
-- Replaces the Google Sheets/Apps Script KV store with real tables. No
-- shared-secret token needed: the anon public API key is meant to be
-- exposed client-side, and access control lives in the RLS policies below
-- instead. This app has no login system, so policies are intentionally
-- permissive (equivalent trust model to the old shared-token setup, where
-- anyone with the token could read/write anything) rather than trying to
-- fake per-user ownership without real auth.

-- Per-device persistent data: name + running stats. One row per browser
-- (device_id is a random UUID generated client-side into localStorage).
create table if not exists devices (
  device_id text primary key,
  name text,
  stats_played int not null default 0,
  stats_wins int not null default 0,
  stats_streak int not null default 0,
  stats_max_streak int not null default 0,
  stats_last_won_slot int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Per-device, per-round state: in-progress/finished guesses, and whether
-- the "last round's answer" reveal banner has been dismissed.
create table if not exists device_rounds (
  device_id text not null,
  slot_index int not null,
  guesses jsonb not null default '[]'::jsonb,
  finished boolean not null default false,
  won boolean not null default false,
  seen_reveal boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (device_id, slot_index)
);

-- Shared leaderboard: one row per (round, player name), visible to everyone
-- playing that round. Intentionally not device-scoped.
create table if not exists results (
  slot_index int not null,
  name text not null,
  guesses int not null,
  won boolean not null,
  device_id text not null,
  ts timestamptz not null default now(),
  -- Keyed by device, not name: a device can only ever hold one row per
  -- round (renaming relabels it), which prevents one device from
  -- reposting its single real result under unlimited aliases. Two
  -- different devices sharing a name (allowed on purpose) still each
  -- get their own row, since they have different device_ids.
  primary key (slot_index, device_id)
);

-- Passive device/browser analytics, upserted on each visit.
create table if not exists device_log (
  device_id text primary key,
  first_seen timestamptz not null default now(),
  last_seen timestamptz not null default now(),
  visits int not null default 1,
  user_agent text,
  platform text,
  language text,
  timezone text,
  screen_w int,
  screen_h int,
  viewport_w int,
  viewport_h int,
  device_pixel_ratio numeric,
  color_scheme text,
  touch boolean,
  hw_concurrency int,
  device_memory numeric,
  connection_type text,
  referrer text
);

alter table devices enable row level security;
alter table device_rounds enable row level security;
alter table results enable row level security;
alter table device_log enable row level security;

create policy "public select devices" on devices for select using (true);
create policy "public insert devices" on devices for insert with check (true);
create policy "public update devices" on devices for update using (true);

create policy "public select device_rounds" on device_rounds for select using (true);
create policy "public insert device_rounds" on device_rounds for insert with check (true);
create policy "public update device_rounds" on device_rounds for update using (true);

create policy "public select results" on results for select using (true);
create policy "public insert results" on results for insert with check (true);
create policy "public update results" on results for update using (true);

create policy "public select device_log" on device_log for select using (true);
create policy "public insert device_log" on device_log for insert with check (true);
create policy "public update device_log" on device_log for update using (true);
