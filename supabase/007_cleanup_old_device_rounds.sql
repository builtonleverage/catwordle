-- Long-term sustainability: device_rounds (per-device, per-round guess
-- state) is the one table that grows unbounded - devices x rounds,
-- forever - while everything else either has lasting value (results
-- backs the all-time medal tally; round_puzzles is small and historical)
-- or is capped at one row per device (devices, device_log).
--
-- The app only ever reads device_rounds for the CURRENT slot_index
-- (loadProgress) or current/previous (initReveal's dismissed-banner
-- check) - anything older is provably dead weight. This runs entirely
-- inside Postgres via pg_cron, so it needs no external scheduler and
-- nobody has to remember to run it.

create extension if not exists pg_cron;

create or replace function cleanup_old_device_rounds() returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  epoch_ms bigint := 1735689600000;
  current_slot int := floor((extract(epoch from now()) * 1000 - epoch_ms) / 43200000);
begin
  -- Keep the current round and one round of buffer; delete anything older.
  delete from device_rounds where slot_index < current_slot - 1;
end;
$$;

-- Runs a minute after each round boundary (00:01 and 12:01 UTC daily),
-- matching the game's own 12-hour round cadence. Unschedule-then-schedule
-- makes this safe to re-run (e.g. if this migration is ever applied
-- twice) without ending up with duplicate cron jobs.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'cleanup-device-rounds') then
    perform cron.unschedule('cleanup-device-rounds');
  end if;
end $$;

select cron.schedule(
  'cleanup-device-rounds',
  '1 0,12 * * *',
  $$select cleanup_old_device_rounds();$$
);
