-- ============================================================
--  Gondar Passport — demo check-in points with easy codes
--
--  Paste this whole file into Supabase → SQL Editor → Run.
--  Then in the app: Passport tab → Check in → tap a demo code
--  (or type it): FASIL1 · BATH2 · DEBRE3 · KUSKUAM4 · RASGIMB5
--
--  Needs migration 0010 (the Passport tables). Safe to run again:
--  existing points are kept, only their codes are set.
--  For the real launch, give each site a new code from the admin
--  ("Gondar Passport" page) so nobody can check in from home.
-- ============================================================

with demo(name_en, name_am, description_en, lat, lng, points, sort_order, code) as (
  values
    ('Fasil Ghebbi', 'ፋሲል ግቢ',
     'The walled royal compound and its castles — a UNESCO World Heritage Site.',
     12.607700, 37.468500, 20, 1, 'FASIL1'),
    ('Fasilides'' Bath', 'የአፄ ፋሲለደስ መዋኛ',
     'The bathing palace filled with water every January for Timket.',
     12.615600, 37.455300, 15, 2, 'BATH2'),
    ('Debre Berhan Selassie', 'ደብረ ብርሃን ሥላሴ',
     'The church famous for its ceiling of painted angels.',
     12.608100, 37.479500, 15, 3, 'DEBRE3'),
    ('Kuskuam', 'ቁስቋም',
     'The 18th-century palace and church of Empress Mentewab.',
     12.626400, 37.442800, 10, 4, 'KUSKUAM4'),
    ('Ras Gimb', 'ራስ ግምብ',
     'A castle-palace near the centre of Gondar, now a museum.',
     12.612900, 37.466800, 10, 5, 'RASGIMB5')
),
added as (
  insert into public.passport_checkpoints
    (name_en, name_am, description_en, lat, lng, points, sort_order, is_active)
  select d.name_en, d.name_am, d.description_en, d.lat, d.lng, d.points, d.sort_order, true
  from demo d
  where not exists (
    select 1 from public.passport_checkpoints c where c.name_en = d.name_en
  )
  returning id
)
select count(*) as new_checkpoints from added;

-- Every checkpoint has a secret row (made by a trigger); set the
-- demo codes on the ones above and make sure they are active.
update public.passport_checkpoints
   set is_active = true
 where name_en in ('Fasil Ghebbi', 'Fasilides'' Bath', 'Debre Berhan Selassie',
                   'Kuskuam', 'Ras Gimb');

insert into public.passport_checkpoint_secrets (checkpoint_id)
select id from public.passport_checkpoints
on conflict (checkpoint_id) do nothing;

update public.passport_checkpoint_secrets s
   set qr_token = v.code, rotated_at = now()
  -- one row per name (the oldest), so each code is used only once
  from (select distinct on (name_en) id, name_en
          from public.passport_checkpoints
         order by name_en, created_at) c
  join (values ('Fasil Ghebbi', 'FASIL1'),
               ('Fasilides'' Bath', 'BATH2'),
               ('Debre Berhan Selassie', 'DEBRE3'),
               ('Kuskuam', 'KUSKUAM4'),
               ('Ras Gimb', 'RASGIMB5')) as v(name_en, code)
    on v.name_en = c.name_en
 where s.checkpoint_id = c.id;

-- Check: five rows, each with its demo code.
select c.sort_order, c.name_en, c.points, s.qr_token as code
from public.passport_checkpoints c
join public.passport_checkpoint_secrets s on s.checkpoint_id = c.id
where s.qr_token in ('FASIL1', 'BATH2', 'DEBRE3', 'KUSKUAM4', 'RASGIMB5')
order by c.sort_order;
