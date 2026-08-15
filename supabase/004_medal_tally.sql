-- All-time gold/silver/bronze medal tally, computed live from `results` -
-- no new table, no sync/cache to keep up to date. Ranks winners within
-- each round by the same rule the frontend uses for per-round badges
-- (fewest guesses, ties broken by earliest finish), takes the top 3, and
-- aggregates counts per player name across every round that's ever been
-- played. Automatically reflects new games the moment they're posted to
-- `results` - there's nothing to run after each round.

create or replace view medal_tally as
with ranked as (
  select
    name,
    rank() over (
      partition by slot_index
      order by guesses asc, ts asc
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
