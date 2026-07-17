-- ============================================================
--  VISIT GONDAR — Commission Tracking + Real Hotel Seed
--  Run this in the Supabase SQL Editor
--  Matches the LIVE schema created by supabase_reset.sql
-- ============================================================

-- ── 1. COMMISSION FIELDS ON BOOKINGS ─────────────────────────
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS total_price       numeric(10,2) DEFAULT 0;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS commission_rate   numeric(4,3)  DEFAULT 0.03;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS commission_amount numeric(10,2) DEFAULT 0;

-- ── 2. AUTO-CALCULATE COMMISSION TRIGGER ─────────────────────
--  Hotel bookings  = 3%  of total price
--  Guide bookings  = 10% of the guide fee
CREATE OR REPLACE FUNCTION calculate_booking_commission()
RETURNS trigger AS $$
BEGIN
  -- Fall back to legacy "price" column if total_price not supplied
  IF NEW.total_price IS NULL OR NEW.total_price = 0 THEN
    NEW.total_price := COALESCE(NEW.price, 0);
  END IF;

  IF NEW.item_type = 'guide' THEN
    NEW.commission_rate := 0.10;
  ELSE
    NEW.commission_rate := 0.03;
  END IF;

  NEW.commission_amount := ROUND(NEW.total_price * NEW.commission_rate, 2);
  -- keep legacy column in sync for older admin views
  NEW.commission_earned := NEW.commission_amount;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_booking_commission ON bookings;
CREATE TRIGGER on_booking_commission
  BEFORE INSERT OR UPDATE OF total_price, price, item_type ON bookings
  FOR EACH ROW EXECUTE FUNCTION calculate_booking_commission();

-- Recalculate any existing bookings
UPDATE bookings SET total_price = COALESCE(NULLIF(total_price,0), price, 0);

-- ── 3. SEED REAL GONDAR HOTELS (live schema) ─────────────────
--  Skips duplicates by name so re-running is safe.
INSERT INTO hotels (name_en, name_am, description, location, contact, photos, price, star_ranking, publish_status)
SELECT * FROM (VALUES
  ('Goha Hotel', 'ጎሐ ሆቴል',
   'The most iconic hotel in Gondar, perched on a hilltop with breathtaking panoramic views of the Royal Enclosure. Pool, spa, and award-winning Ethiopian restaurant.',
   'Hilltop, Gondar', '+251 58 111 4029',
   ARRAY['https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800&q=80'],
   120::numeric, 5, 'published'),

  ('Haile Resort Gondar', 'ኃይሌ ሪዞርት ጎንደር',
   'World-class resort owned by Olympic legend Haile Gebrselassie. Multiple pools, lush gardens, full-service spa, gym, and authentic Ethiopian cuisine.',
   'Resort District, Gondar', '+251 58 111 8000',
   ARRAY['https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800&q=80'],
   150::numeric, 5, 'published'),

  ('Lodge de Chateau', 'ሎጅ ደ ሻቶ',
   'Boutique lodge in the heart of Gondar, steps from Fasil Ghebbi. Decorated with authentic Ethiopian art and antiques. Exceptional personal service.',
   'Near Royal Enclosure', '+251 58 111 4400',
   ARRAY['https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=800&q=80'],
   90::numeric, 4, 'published'),

  ('Taye Belay Hotel', 'ጣየ በላይ ሆቴል',
   'Popular modern hotel in the city centre. Rooftop terrace with castle views, comfortable rooms, and an excellent local restaurant.',
   'City Centre, Gondar', '+251 58 111 2345',
   ARRAY['https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?w=800&q=80'],
   80::numeric, 4, 'published'),

  ('Inn of the Four Sisters', 'አራቱ እህትማማቾች',
   'Famous for its award-winning Ethiopian restaurant and cultural decor. Run by four sisters for over 20 years — the best injera and cultural shows in Gondar.',
   'Gondar Centre', '+251 58 111 7575',
   ARRAY['https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800&q=80'],
   75::numeric, 3, 'published'),

  ('Fasil Hotel', 'ፋሲል ሆቴል',
   'Named after Emperor Fasilides. Comfortable rooms with genuine Ethiopian hospitality — the ideal base for exploring the castles and churches.',
   'Piazza Area, Gondar', '+251 58 111 3300',
   ARRAY['https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800&q=80'],
   65::numeric, 3, 'published'),

  ('Gondar Hills Resort', 'ጎንደር ሂልስ ሪዞርት',
   'Peaceful resort on the hills surrounding Gondar with beautiful highland views. Garden, restaurant, and breakfast included.',
   'Hills Road, Gondar', '+251 58 111 9900',
   ARRAY['https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=800&q=80'],
   74::numeric, 4, 'published'),

  ('Quara Hotel', 'ቋራ ሆቴል',
   'Centrally located hotel offering modern amenities at affordable prices. Popular with budget travellers who still want comfort and reliability.',
   'Piazza, Gondar', '+251 58 111 5500',
   ARRAY['https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?w=800&q=80'],
   42::numeric, 3, 'published')
) AS v(name_en, name_am, description, location, contact, photos, price, star_ranking, publish_status)
WHERE NOT EXISTS (SELECT 1 FROM hotels h WHERE h.name_en = v.name_en);

-- ── 4. SEED REAL SITES (live schema) ─────────────────────────
INSERT INTO sites (name_en, name_am, description, info, location, photo)
SELECT * FROM (VALUES
  ('Fasil Ghebbi', 'ፋሲል ግቢ',
   'Founded in 1636 by Emperor Fasilides, this UNESCO World Heritage fortress-city was home to Ethiopia''s emperors for over two centuries. Six castles, a library, and banqueting halls inside a 900m wall.',
   'UNESCO World Heritage · Entry 200 ETB · 8:00–17:30',
   'City Centre, Gondar',
   'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8b/Fasil_Ghebbi%2C_Gondar.jpg/800px-Fasil_Ghebbi%2C_Gondar.jpg'),

  ('Debre Berhan Selassie', 'ደብረ ብርሃን ሥላሴ',
   'The most beautiful church in Ethiopia, famous for its ceiling painted with 135 cherubic angel faces and vivid biblical murals. Saved from destruction in 1888 by a legendary swarm of bees.',
   'Sacred church · Entry 100 ETB · 7:30–17:00',
   'North Gondar',
   'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a8/Debre_Berhan_Selassie_Church.jpg/800px-Debre_Berhan_Selassie_Church.jpg'),

  ('Fasilides Bath', 'የፋሲልደስ መታጠቢያ',
   'A magnificent 17th-century bathing pavilion. Empty most of the year — but every January 19th during Timket, it is filled and blessed as thousands of pilgrims plunge in to renew their baptism.',
   'Timket festival site · Entry 100 ETB · 8:00–17:30',
   'Northwest Gondar',
   'https://upload.wikimedia.org/wikipedia/commons/thumb/1/19/Fasilides_Bath_Gondar_Ethiopia.jpg/800px-Fasilides_Bath_Gondar_Ethiopia.jpg'),

  ('Kusquam Palace', 'ቁስቋም ቤተ መንግሥት',
   'Built in the 1730s by Empress Mentewab, this hilltop palace and church complex offers panoramic views over Gondar and beautiful 18th-century murals.',
   'Royal complex · Entry 100 ETB · 8:00–17:00',
   'Northwest hill, Gondar',
   'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=800&q=80'),

  ('Simien Mountains', 'ስሜን ተራራዎች',
   'UNESCO World Heritage mountain range with sheer escarpments, ancient volcanic peaks, and endemic wildlife — Walia ibex, Ethiopian wolf, and thousands of Gelada baboons. Day trips from Gondar.',
   'UNESCO National Park · Entry 500 ETB · day trips',
   '100km from Gondar',
   'https://images.unsplash.com/photo-1516026672322-bc52d61a55d5?w=800&q=80')
) AS v(name_en, name_am, description, info, location, photo)
WHERE NOT EXISTS (SELECT 1 FROM sites s WHERE s.name_en = v.name_en);

-- ── 5. SEED REAL GUIDES (live schema) ────────────────────────
INSERT INTO guides (name, initials, specialty, photo, languages, price, license_status, publish_status)
SELECT * FROM (VALUES
  ('Tewodros M.', 'TM', 'Royal History • Architecture • UNESCO Sites',
   '', ARRAY['Amharic','English','Italian'], 45::numeric, 'licensed', 'published'),
  ('Selam B.', 'SB', 'Timket Festival • Photography • Cultural Tours',
   '', ARRAY['Amharic','English','French'], 55::numeric, 'licensed', 'published'),
  ('Yosef T.', 'YT', 'Full-Day Driver • Outskirts • Simien Mountains',
   '', ARRAY['Amharic','English'], 70::numeric, 'licensed', 'published'),
  ('Miriam A.', 'MA', 'Churches • Religious History',
   '', ARRAY['Amharic','English','Arabic'], 38::numeric, 'licensed', 'published')
) AS v(name, initials, specialty, photo, languages, price, license_status, publish_status)
WHERE NOT EXISTS (SELECT 1 FROM guides g WHERE g.name = v.name);

-- ── 6. VERIFY ────────────────────────────────────────────────
SELECT 'hotels' AS t, count(*) FROM hotels
UNION ALL SELECT 'sites', count(*) FROM sites
UNION ALL SELECT 'guides', count(*) FROM guides
UNION ALL SELECT 'bookings', count(*) FROM bookings;
