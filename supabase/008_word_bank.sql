-- Long-term content sustainability: replaces the earlier manually-curated
-- round_puzzles overrides (heavy on dating/lifestyle categories, added by
-- a one-off generation pass) with a large, category-diverse word_bank plus
-- an in-database refresh job. No external generation service, no API
-- costs, nothing to remember to run - runs entirely inside Postgres via
-- pg_cron, same pattern as 007_cleanup_old_device_rounds.sql, and for the
-- same reason: keeps this project on Supabase's free tier forever.
--
-- word_bank is intentionally locked down (RLS on, zero policies) - it's
-- never read by the client, only by refresh_round_puzzles() below, which
-- runs as SECURITY DEFINER and so bypasses RLS as the table owner.

create table if not exists word_bank (
  id serial primary key,
  category text not null,
  word text not null unique,
  constraint word_bank_word_len check (char_length(word) = 5)
);

alter table word_bank enable row level security;

insert into word_bank (category, word) values
  ('ANIMALS','OTTER'),('ANIMALS','PANDA'),('ANIMALS','ZEBRA'),('ANIMALS','LEMUR'),
  ('BIRDS','HERON'),('BIRDS','CRANE'),('BIRDS','STORK'),('BIRDS','RAVEN'),
  ('REPTILES','COBRA'),('REPTILES','GECKO'),('REPTILES','SKINK'),('REPTILES','VIPER'),
  ('SEA LIFE','SQUID'),('SEA LIFE','GUPPY'),('SEA LIFE','MANTA'),('SEA LIFE','TETRA'),
  ('TREES','BIRCH'),('TREES','MAPLE'),('TREES','ALDER'),('TREES','ASPEN'),
  ('FLOWERS','TULIP'),('FLOWERS','DAISY'),('FLOWERS','LILAC'),('FLOWERS','PEONY'),
  ('FRUITS','APPLE'),('FRUITS','PEACH'),('FRUITS','GUAVA'),('FRUITS','PRUNE'),
  ('SPICES','CLOVE'),('SPICES','ANISE'),('SPICES','CHILI'),('SPICES','SUMAC'),
  ('GRAINS & STAPLES','WHEAT'),('GRAINS & STAPLES','MAIZE'),('GRAINS & STAPLES','PASTA'),('GRAINS & STAPLES','BREAD'),
  ('BAKED GOODS','SCONE'),('BAKED GOODS','CRUST'),('BAKED GOODS','DOUGH'),
  ('DRINKS','CIDER'),('DRINKS','JUICE'),('DRINKS','WATER'),('DRINKS','SYRUP'),
  ('COOKING TERMS','BROIL'),('COOKING TERMS','POACH'),('COOKING TERMS','KNEAD'),('COOKING TERMS','GLAZE'),
  ('KITCHEN TOOLS','LADLE'),('KITCHEN TOOLS','GRATE'),('KITCHEN TOOLS','TONGS'),('KITCHEN TOOLS','SIEVE'),
  ('COUNTRIES','EGYPT'),('COUNTRIES','KENYA'),('COUNTRIES','NEPAL'),('COUNTRIES','CHILE'),('COUNTRIES','SPAIN'),
  ('WORLD CITIES','TOKYO'),('WORLD CITIES','PARIS'),('WORLD CITIES','CAIRO'),('WORLD CITIES','MIAMI'),
  ('LANDFORMS','RIDGE'),('LANDFORMS','DELTA'),('LANDFORMS','GORGE'),('LANDFORMS','CLIFF'),
  ('WEATHER','SLEET'),('WEATHER','FROST'),
  ('ASTRONOMY','COMET'),('ASTRONOMY','LUNAR'),('ASTRONOMY','SOLAR'),
  ('GEMSTONES','AMBER'),('GEMSTONES','AGATE'),
  ('METALS','BRASS'),('METALS','STEEL'),
  ('COLORS','UMBER'),('COLORS','KHAKI'),('COLORS','MAUVE'),('COLORS','SEPIA'),
  ('MUSICAL INSTRUMENTS','CELLO'),('MUSICAL INSTRUMENTS','FLUTE'),('MUSICAL INSTRUMENTS','ORGAN'),('MUSICAL INSTRUMENTS','TABLA'),
  ('MUSIC GENRES','OPERA'),('MUSIC GENRES','BLUES'),('MUSIC GENRES','DISCO'),
  ('DANCE STYLES','WALTZ'),('DANCE STYLES','RUMBA'),('DANCE STYLES','SAMBA'),('DANCE STYLES','POLKA'),
  ('SPORTS','RELAY'),('SPORTS','SKATE'),
  ('BOARD & CARD GAMES','CHESS'),('BOARD & CARD GAMES','BINGO'),('BOARD & CARD GAMES','RUMMY'),
  ('FILM & TV','DRAMA'),
  ('MYTHOLOGY','TITAN'),('MYTHOLOGY','ATLAS'),('MYTHOLOGY','NYMPH'),
  ('ZODIAC SIGNS','ARIES'),
  ('PLANETS','PLUTO'),
  ('ELEMENTS','ARGON'),
  ('BODY PARTS','ANKLE'),('BODY PARTS','WRIST'),('BODY PARTS','THIGH'),('BODY PARTS','CHEEK'),
  ('EMOTIONS','PROUD'),('EMOTIONS','EAGER'),('EMOTIONS','WEARY'),('EMOTIONS','TENSE'),
  ('PROFESSIONS','NURSE'),('PROFESSIONS','BAKER'),('PROFESSIONS','JUDGE'),('PROFESSIONS','PILOT'),
  ('TOOLS','LEVEL'),('TOOLS','CLAMP'),('TOOLS','SPADE'),
  ('VEHICLES','TRUCK'),('VEHICLES','TRAIN'),('VEHICLES','PLANE'),('VEHICLES','YACHT'),
  ('CLOTHING','SHIRT'),('CLOTHING','PANTS'),('CLOTHING','SCARF'),('CLOTHING','BOOTS'),
  ('FURNITURE','CHAIR'),('FURNITURE','TABLE'),('FURNITURE','COUCH'),('FURNITURE','SHELF'),
  ('SCHOOL SUBJECTS','MUSIC'),('SCHOOL SUBJECTS','LATIN'),
  ('SCIENCE TERMS','FORCE'),('SCIENCE TERMS','MAGMA'),('SCIENCE TERMS','VIRUS'),('SCIENCE TERMS','LASER'),
  ('COMPUTING','MOUSE'),('COMPUTING','PIXEL'),('COMPUTING','EMAIL'),('COMPUTING','CACHE'),
  ('ART SUPPLIES','BRUSH'),('ART SUPPLIES','EASEL'),('ART SUPPLIES','PAINT'),
  ('NATURAL DISASTERS','FLOOD'),('NATURAL DISASTERS','QUAKE'),('NATURAL DISASTERS','BLAZE'),
  ('CAMPING & OUTDOORS','CANOE'),('CAMPING & OUTDOORS','TRAIL'),('CAMPING & OUTDOORS','TORCH'),
  ('FARM ANIMALS','SHEEP'),('FARM ANIMALS','HORSE')
on conflict (word) do nothing;

-- Tops up the next 60 rounds (~30 days) of round_puzzles from word_bank,
-- skipping any slot that already has an override (so it never clobbers
-- anything, including the existing dating/lifestyle-heavy rows already in
-- place - those just age out naturally as new slots roll past them).
-- Avoids repeating a word within +/-60 slots of itself where the pool
-- allows it, falls back to any word if the pool's ever that exhausted.
create or replace function refresh_round_puzzles() returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  epoch_ms bigint := 1735689600000;
  current_slot int := floor((extract(epoch from now()) * 1000 - epoch_ms) / 43200000);
  target_slot int;
  chosen_category text;
  chosen_word text;
begin
  for target_slot in current_slot..(current_slot + 59) loop
    if exists (select 1 from round_puzzles where slot_index = target_slot) then
      continue;
    end if;

    chosen_category := null;
    chosen_word := null;

    select wb.category, wb.word into chosen_category, chosen_word
    from word_bank wb
    where wb.word not in (
      select rp.word from round_puzzles rp
      where rp.slot_index between target_slot - 60 and target_slot + 60
    )
    order by random()
    limit 1;

    if chosen_word is null then
      select wb.category, wb.word into chosen_category, chosen_word
      from word_bank wb
      order by random()
      limit 1;
    end if;

    insert into round_puzzles (slot_index, category, word, source)
    values (target_slot, chosen_category, chosen_word, 'word_bank')
    on conflict (slot_index) do nothing;
  end loop;
end;
$$;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'refresh-round-puzzles') then
    perform cron.unschedule('refresh-round-puzzles');
  end if;
end $$;

-- Monthly, on the 1st at 00:05 UTC - well ahead of the always-60-round
-- lookahead this writes, so there's no risk of ever running dry between
-- refreshes even if a run is skipped or delayed.
select cron.schedule(
  'refresh-round-puzzles',
  '5 0 1 * *',
  $$select refresh_round_puzzles();$$
);

-- Run once now so today's content starts improving immediately rather
-- than waiting for the 1st of next month.
select refresh_round_puzzles();
