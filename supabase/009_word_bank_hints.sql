-- Hint unlock: once a player has taken more guesses than
-- max(4, this round's live bronze-place guess count), the frontend shows
-- an optional hint for that round's word. Hints are curated once per word
-- here (bounded, one-time authoring task - word_bank is a fixed pool
-- topped up monthly by refresh_round_puzzles(), it doesn't grow per-round,
-- so this never needs re-running for new content).

alter table word_bank add column if not exists hint text;
alter table round_puzzles add column if not exists hint text;

update word_bank set hint = v.hint from (values
  ('OTTER','Playful mammal that floats on its back using a rock to crack shells'),
  ('PANDA','Black-and-white bear that mostly eats bamboo'),
  ('ZEBRA','African plains animal known for its striped coat'),
  ('LEMUR','Wide-eyed primate found only on Madagascar'),
  ('HERON','Long-legged wading bird often seen standing still in shallow water'),
  ('CRANE','Elegant long-necked bird known for elaborate mating dances'),
  ('STORK','Bird associated in folklore with delivering babies'),
  ('RAVEN','Large black bird known for its intelligence and croaking call'),
  ('COBRA','Venomous snake that flares a hood when threatened'),
  ('GECKO','Small lizard famous for climbing walls and ceilings'),
  ('SKINK','Smooth, shiny-scaled lizard found in gardens worldwide'),
  ('VIPER','Snake with hinged fangs that inject venom'),
  ('SQUID','Ten-armed sea creature that squirts ink to escape predators'),
  ('GUPPY','Small, colorful freshwater fish popular in home aquariums'),
  ('MANTA','Giant ocean ray that glides gracefully through open water'),
  ('TETRA','Tiny, brightly colored fish common in tropical fish tanks'),
  ('BIRCH','Tree known for its thin, papery white bark'),
  ('MAPLE','Tree famous for its syrup and star-shaped leaves'),
  ('ALDER','Fast-growing tree often found along riverbanks'),
  ('ASPEN','Tree whose leaves famously tremble in the slightest breeze'),
  ('TULIP','Cup-shaped spring flower once the center of a Dutch trading craze'),
  ('DAISY','Simple flower with white petals around a yellow center'),
  ('LILAC','Fragrant purple flowering shrub that blooms in spring'),
  ('PEONY','Lush, full-petaled flower popular in bridal bouquets'),
  ('APPLE','Crisp fruit that famously fell near a certain scientist'),
  ('PEACH','Fuzzy-skinned stone fruit with sweet, juicy flesh'),
  ('GUAVA','Tropical fruit with fragrant pink or white flesh'),
  ('PRUNE','Dried version of a purple stone fruit'),
  ('CLOVE','Aromatic spice often used in holiday baking'),
  ('ANISE','Spice with a licorice-like flavor'),
  ('CHILI','Spicy pepper that brings the heat to a dish'),
  ('SUMAC','Tangy, deep-red spice common in Middle Eastern cooking'),
  ('WHEAT','Cereal grain ground into most of the world''s flour'),
  ('MAIZE','Another name for corn'),
  ('PASTA','Italian staple made from durum wheat and water'),
  ('BREAD','Baked staple made from flour, water, and yeast'),
  ('SCONE','Crumbly baked good often served with clotted cream'),
  ('CRUST','The outer, often flaky layer of a pie or loaf'),
  ('DOUGH','Soft, workable mixture before it''s baked into bread'),
  ('CIDER','Fermented or fresh drink pressed from apples'),
  ('JUICE','Liquid extracted from fruit or vegetables'),
  ('WATER','The most essential drink of all'),
  ('SYRUP','Thick, sweet liquid poured over pancakes'),
  ('BROIL','Cooking method using direct, intense heat from above'),
  ('POACH','Gently cooking food in barely simmering liquid'),
  ('KNEAD','Working dough with your hands to develop gluten'),
  ('GLAZE','A shiny, sweet coating brushed onto baked goods'),
  ('LADLE','Long-handled spoon used for serving soup'),
  ('GRATE','Tool used to shred cheese or zest citrus'),
  ('TONGS','Hinged tool used for gripping and flipping food'),
  ('SIEVE','Mesh tool used for straining or sifting'),
  ('EGYPT','Country home to the Great Pyramids and the Nile'),
  ('KENYA','East African country famous for long-distance runners and safaris'),
  ('NEPAL','Himalayan country home to Mount Everest'),
  ('CHILE','Long, narrow South American country hugging the Pacific coast'),
  ('SPAIN','European country known for flamenco and paella'),
  ('TOKYO','Capital of Japan and one of the world''s largest cities'),
  ('PARIS','French capital known for its iron tower'),
  ('CAIRO','Egyptian capital near the Great Pyramids'),
  ('MIAMI','Sunny Florida city known for its beaches and nightlife'),
  ('RIDGE','A long, narrow elevated strip of land'),
  ('DELTA','Landform where a river fans out before meeting the sea'),
  ('GORGE','A deep, narrow valley carved by a river'),
  ('CLIFF','A steep rock face, often overlooking the sea'),
  ('SLEET','Wintry mix of rain and ice pellets'),
  ('FROST','Thin icy coating that forms on cold surfaces overnight'),
  ('COMET','Icy space object that grows a glowing tail near the sun'),
  ('LUNAR','Relating to the moon'),
  ('SOLAR','Relating to the sun'),
  ('AMBER','Fossilized tree resin, sometimes trapping ancient insects'),
  ('AGATE','Banded gemstone prized for its colorful layered patterns'),
  ('BRASS','Golden-toned metal alloy of copper and zinc'),
  ('STEEL','Strong metal alloy made mostly of iron and carbon'),
  ('UMBER','Warm brown pigment used since ancient cave paintings'),
  ('KHAKI','Dusty tan color, also a name for certain trousers'),
  ('MAUVE','Soft, pale purplish-pink shade'),
  ('SEPIA','Warm brownish tone associated with old photographs'),
  ('CELLO','Large stringed instrument played while seated, held between the knees'),
  ('FLUTE','Slender wind instrument played by blowing across a hole'),
  ('ORGAN','Instrument with pipes or keys often heard in churches'),
  ('TABLA','Pair of hand drums central to Indian classical music'),
  ('OPERA','Dramatic musical art form combining singing and orchestra'),
  ('BLUES','Soulful music genre rooted in African American history'),
  ('DISCO','Danceable genre with a signature four-on-the-floor beat'),
  ('WALTZ','Elegant ballroom dance in three-quarter time'),
  ('RUMBA','Sultry Latin dance known for its hip movement'),
  ('SAMBA','Lively Brazilian dance associated with Carnival'),
  ('POLKA','Lively, bouncy couple''s dance of Central European origin'),
  ('RELAY','Track event where a baton is passed between teammates'),
  ('SKATE','Sport of gliding on wheels or blades'),
  ('CHESS','Strategy game played on a black-and-white board'),
  ('BINGO','Game of chance where numbers are called and matched on a card'),
  ('RUMMY','Card game built around forming sets and runs'),
  ('DRAMA','Genre built around serious, emotional storytelling'),
  ('TITAN','Member of a race of powerful deities that came before the Greek gods'),
  ('ATLAS','Greek figure condemned to hold up the sky'),
  ('NYMPH','Minor nature deity often tied to rivers or forests in myth'),
  ('ARIES','First sign of the zodiac, symbolized by the ram'),
  ('PLUTO','Distant dwarf planet once considered the ninth planet'),
  ('ARGON','Inert noble gas used in light bulbs'),
  ('ANKLE','Joint connecting the foot to the leg'),
  ('WRIST','Joint connecting the hand to the forearm'),
  ('THIGH','The upper part of the leg, above the knee'),
  ('CHEEK','The soft part of the face below the eye'),
  ('PROUD','Feeling of deep satisfaction in an achievement'),
  ('EAGER','Feeling of enthusiastic anticipation'),
  ('WEARY','Feeling of deep tiredness'),
  ('TENSE','Feeling of nervous strain'),
  ('NURSE','Healthcare worker who cares for patients alongside doctors'),
  ('BAKER','Someone whose trade is making bread and pastries'),
  ('JUDGE','Presides over a courtroom and decides legal matters'),
  ('PILOT','Person trained to fly an aircraft'),
  ('LEVEL','Tool used to check whether a surface is perfectly horizontal'),
  ('CLAMP','Tool used to hold two pieces of material tightly together'),
  ('SPADE','Digging tool with a flat blade'),
  ('TRUCK','Large vehicle built for hauling goods'),
  ('TRAIN','Vehicle that runs on rails, made of linked cars'),
  ('PLANE','Vehicle that flies using fixed wings'),
  ('YACHT','Luxurious vessel used for pleasure cruising or racing'),
  ('SHIRT','Upper-body garment usually with sleeves and a collar'),
  ('PANTS','Garment covering the legs separately'),
  ('SCARF','Strip of fabric worn around the neck for warmth or style'),
  ('BOOTS','Sturdy footwear that covers the ankle or higher'),
  ('CHAIR','Piece of furniture built for one person to sit on'),
  ('TABLE','Flat-surfaced furniture piece supported by legs'),
  ('COUCH','Long, cushioned seat for multiple people'),
  ('SHELF','Flat surface fixed to a wall for storing items'),
  ('MUSIC','Subject focused on rhythm, melody, and performance'),
  ('LATIN','Ancient language still studied for its influence on modern ones'),
  ('FORCE','A push or pull that changes an object''s motion'),
  ('MAGMA','Molten rock found beneath the Earth''s surface'),
  ('VIRUS','Microscopic agent that needs a host cell to reproduce'),
  ('LASER','Device that emits a focused, intense beam of light'),
  ('MOUSE','Handheld device used to point and click on a screen'),
  ('PIXEL','The smallest unit of a digital image'),
  ('EMAIL','Digital message sent over the internet'),
  ('CACHE','Temporary storage that speeds up repeated access to data'),
  ('BRUSH','Tool with bristles used to apply paint'),
  ('EASEL','Stand that holds a canvas upright while painting'),
  ('PAINT','Pigmented liquid applied with a brush'),
  ('FLOOD','Disaster caused by an overflow of water onto normally dry land'),
  ('QUAKE','Sudden shaking of the ground caused by shifting tectonic plates'),
  ('BLAZE','A large, fast-spreading fire'),
  ('CANOE','Narrow boat propelled with a single-bladed paddle'),
  ('TRAIL','Marked path through the wilderness for hiking'),
  ('TORCH','Portable light source, often a flaming stick or handheld lamp'),
  ('SHEEP','Farm animal raised for wool and meat, known for flocking together'),
  ('HORSE','Farm animal often ridden or used to pull carts')
) as v(word, hint)
where word_bank.word = v.word;

-- Backfill any current/future round_puzzles rows sourced from word_bank.
-- Past rounds are already finished and their hint is never read, so this
-- intentionally doesn't touch anything before "now".
update round_puzzles rp
set hint = wb.hint
from word_bank wb
where rp.word = wb.word and rp.hint is null;

-- Carry hint through the monthly top-up job going forward.
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
  chosen_hint text;
begin
  for target_slot in current_slot..(current_slot + 59) loop
    if exists (select 1 from round_puzzles where slot_index = target_slot) then
      continue;
    end if;

    chosen_category := null;
    chosen_word := null;
    chosen_hint := null;

    select wb.category, wb.word, wb.hint into chosen_category, chosen_word, chosen_hint
    from word_bank wb
    where wb.word not in (
      select rp.word from round_puzzles rp
      where rp.slot_index between target_slot - 60 and target_slot + 60
    )
    order by random()
    limit 1;

    if chosen_word is null then
      select wb.category, wb.word, wb.hint into chosen_category, chosen_word, chosen_hint
      from word_bank wb
      order by random()
      limit 1;
    end if;

    insert into round_puzzles (slot_index, category, word, source, hint)
    values (target_slot, chosen_category, chosen_word, 'word_bank', chosen_hint)
    on conflict (slot_index) do nothing;
  end loop;
end;
$$;
