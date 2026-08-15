-- Closes an exploit: results was previously keyed by (slot_index, name),
-- which meant renaming after finishing (nameSave's `if(finished) await
-- postResult(won)`) created a BRAND NEW row under the new name instead of
-- relabeling the existing one - since nothing stopped one device from
-- reposting its single real result under an unlimited number of aliases,
-- flooding the leaderboard and medal tally with fake duplicate entries
-- all derived from one real play.
--
-- Re-keying by (slot_index, device_id) instead means each device can only
-- ever hold one row per round, full stop - renaming now correctly just
-- relabels that one row. This also still handles two different devices
-- legitimately sharing a name (allowed on purpose - see device-count
-- indicator) correctly: each gets its own row, since they have different
-- device_ids.

alter table results drop constraint results_pkey;
alter table results alter column device_id set not null;
alter table results add primary key (slot_index, device_id);
