-- Locks down public access ahead of the repo/site going public.
--
-- Until now every table's RLS policies were `using (true)`, so anyone
-- holding the (intentionally public) anon key could:
--   - UPDATE any row in results/devices/device_rounds/device_log, e.g.
--     rename every player on the leaderboard or rewrite their scores
--     with one PATCH request that has no filter at all;
--   - read every visitor's device_log row (user agent, timezone,
--     language, screen, referrer);
--   - read round_puzzles for future slots, i.e. upcoming answers (the
--     monthly refresh job fills ~30 days ahead);
--   - read every device_id, which is the only thing that identifies a
--     player, and every league's membership list;
--   - call the SECURITY DEFINER maintenance functions through /rpc.
--
-- New model: device_id is treated as the device's private credential.
-- The page sends it as an `x-device-id` request header, PostgREST exposes
-- request headers to Postgres, and the per-device tables only let a
-- request see/write rows whose device_id matches that header. Public
-- reads (leaderboard, device counts, league boards) go through views and
-- a function that never return device_id.
--
-- Requires 010_league_members.sql to have been run first. Safe to re-run.
--
-- Rollout: run this in the SQL Editor, then deploy the matching frontend
-- right away - the previous frontend doesn't send x-device-id, so its
-- writes are rejected once this is applied (reads of the board fail
-- softly, same as any other network error).

-- ---------- Helpers ----------

-- The calling device's id, from the x-device-id header PostgREST forwards
-- as the request.headers setting. NULL when absent, which matches no row.
create or replace function request_device_id() returns text
language sql stable
as $$
  select nullif(current_setting('request.headers', true), '')::json->>'x-device-id'
$$;

-- Same 12-hour slot numbering as the frontend and the cron jobs.
create or replace function current_slot() returns int
language sql stable
as $$
  select floor((extract(epoch from now()) * 1000 - 1735689600000) / 43200000)::int
$$;

-- ---------- devices ----------
drop policy if exists "public select devices" on devices;
drop policy if exists "public insert devices" on devices;
drop policy if exists "public update devices" on devices;
drop policy if exists "own select devices" on devices;
create policy "own select devices" on devices for select using (device_id = request_device_id());
drop policy if exists "own insert devices" on devices;
create policy "own insert devices" on devices for insert with check (device_id = request_device_id());
drop policy if exists "own update devices" on devices;
create policy "own update devices" on devices for update using (device_id = request_device_id()) with check (device_id = request_device_id());

-- ---------- device_rounds ----------
drop policy if exists "public select device_rounds" on device_rounds;
drop policy if exists "public insert device_rounds" on device_rounds;
drop policy if exists "public update device_rounds" on device_rounds;
drop policy if exists "own select device_rounds" on device_rounds;
create policy "own select device_rounds" on device_rounds for select using (device_id = request_device_id());
drop policy if exists "own insert device_rounds" on device_rounds;
create policy "own insert device_rounds" on device_rounds for insert with check (device_id = request_device_id());
drop policy if exists "own update device_rounds" on device_rounds;
create policy "own update device_rounds" on device_rounds for update using (device_id = request_device_id()) with check (device_id = request_device_id());

-- ---------- results ----------
drop policy if exists "public select results" on results;
drop policy if exists "public insert results" on results;
drop policy if exists "public update results" on results;
drop policy if exists "own select results" on results;
create policy "own select results" on results for select using (device_id = request_device_id());
drop policy if exists "own insert results" on results;
create policy "own insert results" on results for insert with check (device_id = request_device_id());
drop policy if exists "own update results" on results;
create policy "own update results" on results for update using (device_id = request_device_id()) with check (device_id = request_device_id());

-- ---------- device_log ----------
drop policy if exists "public select device_log" on device_log;
drop policy if exists "public insert device_log" on device_log;
drop policy if exists "public update device_log" on device_log;
drop policy if exists "own select device_log" on device_log;
create policy "own select device_log" on device_log for select using (device_id = request_device_id());
drop policy if exists "own insert device_log" on device_log;
create policy "own insert device_log" on device_log for insert with check (device_id = request_device_id());
drop policy if exists "own update device_log" on device_log;
create policy "own update device_log" on device_log for update using (device_id = request_device_id()) with check (device_id = request_device_id());

-- ---------- league_members ----------
-- Membership lists are no longer browsable (that exposed every member's
-- device_id and every league code); boards are read via league_results().
-- The update policy only exists so re-joining via the client's upsert
-- doesn't error on the existing row.
drop policy if exists "public select league_members" on league_members;
drop policy if exists "public insert league_members" on league_members;
drop policy if exists "own select league_members" on league_members;
create policy "own select league_members" on league_members for select using (device_id = request_device_id());
drop policy if exists "own insert league_members" on league_members;
create policy "own insert league_members" on league_members for insert with check (device_id = request_device_id());
drop policy if exists "own update league_members" on league_members;
create policy "own update league_members" on league_members for update using (device_id = request_device_id()) with check (device_id = request_device_id());

-- ---------- round_puzzles ----------
-- Current and past rounds only - future rows are upcoming answers.
drop policy if exists "public select round_puzzles" on round_puzzles;
drop policy if exists "past and current round_puzzles" on round_puzzles;
create policy "past and current round_puzzles" on round_puzzles for select using (slot_index <= current_slot());

-- ---------- Server-side sanity limits ----------
-- The 16-char name cap and 1-6 guesses were only enforced in the browser.
-- NOT VALID: enforced for every new/updated row without failing on any
-- legacy row that predates the check.
alter table results drop constraint if exists results_name_len;
alter table results add constraint results_name_len check (char_length(btrim(name)) between 1 and 16) not valid;
alter table results drop constraint if exists results_guesses_range;
alter table results add constraint results_guesses_range check (guesses between 1 and 6) not valid;
alter table results drop constraint if exists results_solve_ms_range;
alter table results add constraint results_solve_ms_range check (solve_ms is null or solve_ms >= 0) not valid;
alter table devices drop constraint if exists devices_name_len;
alter table devices add constraint devices_name_len check (name is null or char_length(btrim(name)) between 1 and 16) not valid;

-- ---------- Public read paths (no device_id) ----------
-- Views run with their owner's rights, so these read past the own-row
-- RLS above while only exposing the listed columns - same as medal_tally.

-- Everyone's results for the leaderboard.
create or replace view public_results as
select slot_index, name, guesses, won, ts, solve_ms
from results;

-- How many distinct devices have ever used each name (the leaderboard's
-- multi-device badge), without listing the devices themselves.
create or replace view name_device_counts as
select name, count(*)::int as devices
from devices
where name is not null
group by name;

grant select on public_results to anon, authenticated;
grant select on name_device_counts to anon, authenticated;

-- A league's board for one round. Needs the code, so leagues can't be
-- enumerated - knowing the invite code is what grants a view of the board.
create or replace function league_results(p_slot int, p_code text)
returns table (slot_index int, name text, guesses int, won boolean, ts timestamptz, solve_ms int)
language sql stable
security definer
set search_path = public
as $$
  select r.slot_index, r.name, r.guesses, r.won, r.ts, r.solve_ms
  from results r
  join league_members m on m.device_id = r.device_id
  where r.slot_index = p_slot and m.league_code = upper(p_code)
$$;

revoke execute on function league_results(int, text) from public;
grant execute on function league_results(int, text) to anon, authenticated;

-- ---------- Maintenance functions: cron only ----------
-- Supabase grants EXECUTE on public-schema functions to anon by default,
-- which exposed these at /rest/v1/rpc/... pg_cron runs them as the owner.
revoke execute on function cleanup_old_device_rounds() from public, anon, authenticated;
revoke execute on function refresh_round_puzzles() from public, anon, authenticated;
