-- Private "leagues": a device joins a league by visiting an invite link
-- (?league=CODE) or by generating one in the UI. Membership is just a
-- device_id <-> league_code mapping; the leaderboard for a given round is
-- unchanged (still one shared `results` table) and is filtered client-side
-- to members of the active league when one is selected. No new write path
-- for game results - this only scopes which existing rows are displayed.
create table if not exists league_members (
  device_id text not null,
  league_code text not null,
  joined_at timestamptz not null default now(),
  primary key (device_id, league_code)
);

alter table league_members enable row level security;

create policy "public select league_members" on league_members for select using (true);
create policy "public insert league_members" on league_members for insert with check (true);
