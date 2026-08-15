-- Solve-time tiebreak: previously ties (equal guess count) broke by
-- absolute finish timestamp (ts), which unfairly favors whoever opened
-- the app earliest in the round rather than whoever actually solved it
-- fastest once they engaged. solve_ms captures each player's own elapsed
-- time (first guess submitted -> winning guess submitted) and becomes
-- the tiebreak instead.

alter table results add column if not exists solve_ms int;
alter table device_rounds add column if not exists first_guess_at timestamptz;

-- Legacy rows with no solve_ms recorded fall back to ts so old data
-- doesn't sort chaotically relative to itself.
create or replace view medal_tally as
with ranked as (
  select
    name,
    rank() over (
      partition by slot_index
      order by guesses asc, coalesce(solve_ms, 2147483647) asc, ts asc
    ) as rnk
  from results
  where won = true
)
select
  name,
  count(*) filter (where rnk = 1) as gold,
  count(*) filter (where rnk = 2) as silver,
  count(*) filter (where rnk = 3) as bronze,
  count(*) as total_medals
from ranked
where rnk <= 3
group by name
order by gold desc, silver desc, bronze desc, name asc;

grant select on medal_tally to anon;
