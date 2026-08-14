-- Adds an override table for auto-generated puzzle content. The existing
-- hardcoded BANK array + seeded shuffle in src/index.template.html stays
-- exactly as-is and is the permanent fallback for any slot_index without a
-- row here. This means: (1) every slot already played keeps working
-- identically forever, zero migration needed, and (2) if the scheduled
-- generation job ever stops running, the game keeps working fine off the
-- existing fallback - nothing here is required for the game to function.
--
-- Only the service_role key can write to this table (no insert/update
-- policy for anon/authenticated) since it controls what every visitor
-- sees for a round - unlike the other tables, public write here would let
-- anyone deface the live game content.

create table if not exists round_puzzles (
  slot_index int primary key,
  category text not null,
  word text not null,
  source text not null default 'generated',
  created_at timestamptz not null default now()
);

alter table round_puzzles enable row level security;

create policy "public select round_puzzles" on round_puzzles for select using (true);
