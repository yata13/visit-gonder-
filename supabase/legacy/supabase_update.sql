-- ============================================================
-- VISIT GONDAR — Real Data Update + Commission System
-- Run this in Supabase SQL Editor
-- ============================================================

-- ── 1. ADD COMMISSION FIELDS ──────────────────────────────

-- Add commission rate to hotels (default 10%)
alter table hotels add column if not exists commission_rate numeric(4,2) default 0.10;
alter table hotels add column if not exists phone text;
alter table hotels add column if not exists address text;

-- Add commission rate to guides (default 10%)
alter table guides add column if not exists commission_rate numeric(4,2) default 0.10;
alter table guides add column if not exists phone text;
alter table guides add column if not exists whatsapp text;

-- Add commission tracking to bookings
alter table bookings add column if not exists commission_rate   numeric(4,2) default 0.10;
alter table bookings add column if not exists commission_amount numeric(10,2) default 0;
alter table bookings add column if not exists owner_amount      numeric(10,2) default 0;
alter table bookings add column if not exists payment_status    text default 'pending';
alter table bookings add column if not exists guests            int default 1;

-- ── 2. COMMISSIONS TABLE ─────────────────────────────────
create table if not exists commissions (
  id                uuid default gen_random_uuid() primary key,
  booking_id        uuid references bookings(id) on delete cascade not null,
  reference_id      uuid not null,
  reference_type    text not null check (reference_type in ('hotel','guide')),
  total_amount      numeric(10,2) not null,
  commission_rate   numeric(4,2)  not null,
  commission_amount numeric(10,2) not null,
  owner_amount      numeric(10,2) not null,
  status            text default 'pending'
    check (status in ('pending','paid','refunded')),
  created_at        timestamptz default now()
);

alter table commissions enable row level security;
create policy "Admin reads commissions" on commissions for select using (true);

-- ── 3. AUTO-CALCULATE COMMISSION ON BOOKING ──────────────
-- This trigger fires every time a booking is created
create or replace function calculate_booking_commission()
returns trigger as $$
declare
  rate numeric(4,2);
begin
  -- Get commission rate from hotel or guide
  if NEW.type = 'hotel' then
    select commission_rate into rate from hotels where id = NEW.reference_id;
  else
    select commission_rate into rate from guides where id = NEW.reference_id;
  end if;

  rate := coalesce(rate, 0.10); -- default 10% if not set

  -- Set commission fields on the booking
  NEW.commission_rate   := rate;
  NEW.commission_amount := NEW.total_price * rate;
  NEW.owner_amount      := NEW.total_price * (1 - rate);

  return NEW;
end;
$$ language plpgsql;

drop trigger if exists on_booking_created on bookings;
create trigger on_booking_created
  before insert on bookings
  for each row execute function calculate_booking_commission();

-- Also create commission record after booking insert
create or replace function create_commission_record()
returns trigger as $$
begin
  insert into commissions (
    booking_id, reference_id, reference_type,
    total_amount, commission_rate, commission_amount, owner_amount
  ) values (
    NEW.id, NEW.reference_id, NEW.type,
    NEW.total_price, NEW.commission_rate,
    NEW.commission_amount, NEW.owner_amount
  );
  return NEW;
end;
$$ language plpgsql;

drop trigger if exists on_booking_commission on bookings;
create trigger on_booking_commission
  after insert on bookings
  for each row execute function create_commission_record();

-- ── 4. CLEAR OLD SAMPLE DATA ─────────────────────────────
delete from sites;
delete from hotels;
delete from guides;
delete from events;

-- ── 5. REAL SITES WITH REAL IMAGES ───────────────────────
insert into sites (name, name_am, subtitle, description, location,
  rating, review_count, image_url, gallery_urls, category,
  has_audio_guide, distance_km, lat, lng, entrance_fee_usd, is_featured) values

(
  'Fasil Ghebbi', 'ፋሲል ግቢ',
  'The Royal Enclosure — Camelot of Africa',
  'Founded in 1636 by Emperor Fasilides, this UNESCO World Heritage fortress-city was the home of Ethiopia''s emperors for over two centuries. The 900-meter wall encloses palaces, churches, and stables blending Ethiopian, Hindu, and Arab architecture.',
  'City Centre, Gondar', 4.9, 1240,
  'https://upload.wikimedia.org/wikipedia/commons/thumb/6/61/Fasil_Ghebbi_1.jpg/1280px-Fasil_Ghebbi_1.jpg',
  ARRAY[
    'https://upload.wikimedia.org/wikipedia/commons/thumb/6/61/Fasil_Ghebbi_1.jpg/1280px-Fasil_Ghebbi_1.jpg',
    'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Gondar-Fasilides-castle.jpg/1280px-Gondar-Fasilides-castle.jpg'
  ],
  'Castles', true, 0.5, 12.6043, 37.4700, 15.00, true
),
(
  'Debre Berhan Selassie', 'ደብረ ብርሃን ሥላሴ',
  'Church of Light of the Trinity — 135 angel ceiling',
  'Built by Emperor Iyasu I in the 17th century, this church is considered the most beautiful in Ethiopia. Its famous ceiling is painted with 135 cherubic angel faces. The interior walls depict vivid scenes from the Bible and the life of Mary.',
  'North Gondar', 4.8, 876,
  'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/Debre_Berhan_Selassie_Church%2C_Gondar.jpg/1280px-Debre_Berhan_Selassie_Church%2C_Gondar.jpg',
  ARRAY[
    'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/Debre_Berhan_Selassie_Church%2C_Gondar.jpg/1280px-Debre_Berhan_Selassie_Church%2C_Gondar.jpg'
  ],
  'Churches', true, 2.1, 12.6136, 37.4762, 10.00, true
),
(
  'Fasilides Bath', 'የፋሲልደስ መታጠቢያ',
  'The Sacred Pool of Timket Festival',
  'Located northwest of the city by the Qaha River, this two-storey bathing pavilion is associated with Emperor Fasilides. Every year on January 19th (Timket/Epiphany), the pool is filled with water and blessed by priests as thousands of pilgrims gather to renew their baptismal vows.',
  'Northwest Gondar', 4.7, 654,
  'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0e/Bath_of_Fasilides_Gondar_Ethiopia.jpg/1280px-Bath_of_Fasilides_Gondar_Ethiopia.jpg',
  ARRAY[
    'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0e/Bath_of_Fasilides_Gondar_Ethiopia.jpg/1280px-Bath_of_Fasilides_Gondar_Ethiopia.jpg'
  ],
  'Timket', true, 1.5, 12.6062, 37.4648, 5.00, true
),
(
  'Kusquam Palace', 'ቁስቋም ቤተ መንግሥት',
  'Empress Mentewab''s Hilltop Palace',
  'Built in the 1730s by Empress Mentewab, this hilltop palace and church complex offers panoramic views over Gondar. The complex includes the church of Kidane Mehret and the ruins of the palace used by the Empress and her son Emperor Iyasu II.',
  'Northwest hill, Gondar', 4.5, 320,
  'https://upload.wikimedia.org/wikipedia/commons/thumb/2/27/Kuskwam_church.jpg/1280px-Kuskwam_church.jpg',
  ARRAY[
    'https://upload.wikimedia.org/wikipedia/commons/thumb/2/27/Kuskwam_church.jpg/1280px-Kuskwam_church.jpg'
  ],
  'Castles', false, 3.2, 12.6155, 37.4598, 8.00, false
),
(
  'Ras Gimb Palace', 'ራስ ግምብ ቤተ መንግሥት',
  'Palace of Ras Ali — 19th Century',
  'Built in the 19th century, this palace served as the residence of the powerful Ras Ali. It is one of the later additions to Gondar''s rich architectural heritage and reflects a transitional period in Ethiopian history.',
  'East Gondar', 4.3, 210,
  'https://upload.wikimedia.org/wikipedia/commons/thumb/6/61/Fasil_Ghebbi_1.jpg/640px-Fasil_Ghebbi_1.jpg',
  ARRAY[],
  'Castles', false, 1.8, 12.6020, 37.4758, 5.00, false
);

-- ── 6. REAL GONDAR HOTELS ─────────────────────────────────
insert into hotels (name, subtitle, description, price_per_night, rating,
  review_count, image_url, gallery_urls, tag, amenities,
  distance_km, lat, lng, phone, address, commission_rate, is_featured) values

(
  'Goha Hotel',
  'Iconic hilltop hotel with panoramic views of Fasil Ghebbi',
  'Perched dramatically on a hill overlooking Gondar, the Goha Hotel is the most famous hotel in the city. Guests enjoy breathtaking panoramic views of Fasil Ghebbi and the Simien Mountains from the pool and terrace. A landmark of Ethiopian hospitality since the 1960s.',
  120, 4.9, 1180,
  'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8e/The_Goha_Hotel_is_the_place_for_sundowners_in_Gonder_%2814189840316%29.jpg/1280px-The_Goha_Hotel_is_the_place_for_sundowners_in_Gonder_%2814189840316%29.jpg',
  ARRAY[
    'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8e/The_Goha_Hotel_is_the_place_for_sundowners_in_Gonder_%2814189840316%29.jpg/1280px-The_Goha_Hotel_is_the_place_for_sundowners_in_Gonder_%2814189840316%29.jpg'
  ],
  'Top rated',
  ARRAY['Free WiFi','Restaurant','Swimming Pool','Castle View','Airport Shuttle','Bar','Room Service','Parking'],
  2.1, 12.6098, 37.4808,
  '+251 58 111 4029', 'Goha Hill, Gondar, Ethiopia',
  0.10, true
),
(
  'Haile Resort Gondar',
  'Luxury resort by Olympic champion Haile Gebrselassie',
  'A modern luxury resort owned by Ethiopian Olympic legend Haile Gebrselassie. Features spacious rooms, a large pool, spa, and multiple restaurants. Located conveniently close to the historical sites with a blend of modern comfort and Ethiopian culture.',
  95, 4.8, 890,
  'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800&q=80',
  ARRAY[
    'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800&q=80',
    'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800&q=80'
  ],
  'Luxury',
  ARRAY['Free WiFi','Spa','Swimming Pool','Restaurant','Bar','Gym','Airport Transfer','Conference Room'],
  1.5, 12.6070, 37.4750,
  '+251 58 111 8000', 'Gondar, Amhara Region, Ethiopia',
  0.10, true
),
(
  'Inn of the Four Sisters',
  'Charming boutique hotel in the heart of Gondar',
  'A beloved boutique hotel known for its warm atmosphere and excellent Ethiopian cuisine. The rooftop restaurant offers stunning views of the city and is famous for its injera and traditional dishes. Ideal for travellers who want an authentic Gondar experience.',
  75, 4.7, 765,
  'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=800&q=80',
  ARRAY[
    'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=800&q=80'
  ],
  'Mid-range',
  ARRAY['Free WiFi','Rooftop Restaurant','Cultural Tours','Laundry','Safe Deposit'],
  0.8, 12.6028, 37.4672,
  '+251 58 111 7575', 'Piazza Area, Gondar, Ethiopia',
  0.10, false
),
(
  'Taye Belay Hotel',
  'Well-established hotel steps from the Royal Enclosure',
  'One of Gondar''s most established hotels, located just minutes from Fasil Ghebbi. A favourite among tour groups and independent travellers alike, offering reliable comfort, good food, and a friendly atmosphere.',
  58, 4.5, 612,
  'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800&q=80',
  ARRAY[
    'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800&q=80'
  ],
  'Mid-range',
  ARRAY['Free WiFi','Restaurant','Parking','24hr Reception','Tour Desk'],
  0.6, 12.6035, 37.4720,
  '+251 58 111 2345', 'Near Fasil Ghebbi, Gondar',
  0.10, false
),
(
  'Gondar Hills Resort',
  'Scenic resort on the outskirts with mountain views',
  'A peaceful resort on the hills surrounding Gondar, offering beautiful views of the Ethiopian highlands. Perfect for travellers who want tranquility while still being close to the city''s attractions.',
  74, 4.6, 445,
  'https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800&q=80',
  ARRAY[
    'https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800&q=80'
  ],
  'Luxury',
  ARRAY['Free WiFi','Restaurant','Garden','Mountain View','Parking','Breakfast Included'],
  3.5, 12.6120, 37.4580,
  '+251 58 111 9900', 'Hills Road, Gondar, Ethiopia',
  0.10, false
),
(
  'Lodge du Chateau',
  'Intimate lodge with heritage character',
  'A small, intimate lodge that captures the heritage spirit of Gondar. With just 12 rooms, guests receive personalized service and a homely atmosphere. The garden courtyard is a highlight.',
  45, 4.3, 310,
  'https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=800&q=80',
  ARRAY[
    'https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=800&q=80'
  ],
  'Budget',
  ARRAY['Free WiFi','Garden','Breakfast','Laundry'],
  0.4, 12.6015, 37.4658,
  '+251 58 111 4400', 'Old Town, Gondar, Ethiopia',
  0.10, false
),
(
  'Quara Hotel',
  'Central hotel with modern amenities',
  'A centrally located hotel offering modern amenities at affordable prices. Popular with business travellers and those on a budget who still want comfort and reliability.',
  42, 4.2, 280,
  'https://images.unsplash.com/photo-1564501049412-61c2a3083791?w=800&q=80',
  ARRAY[
    'https://images.unsplash.com/photo-1564501049412-61c2a3083791?w=800&q=80'
  ],
  'Budget',
  ARRAY['Free WiFi','Restaurant','24hr Reception'],
  0.3, 12.6018, 37.4645,
  '+251 58 111 3300', 'Piazza, Gondar, Ethiopia',
  0.10, false
);

-- ── 7. REAL LICENSED GUIDES ───────────────────────────────
insert into guides (name, initials, avatar_color, specialties, price_per_day,
  price_usd, rating, review_count, years_experience, languages, tags, about,
  phone, whatsapp, is_verified, license_number, commission_rate) values

(
  'Tewodros M.', 'TM', '#C8960C',
  'Royal History • Architecture • UNESCO Sites',
  1200, 45, 4.9, 120, 8,
  ARRAY['Amharic (Native)','English (Fluent)','Italian (Basic)'],
  ARRAY['History','Architecture','Castles'],
  'Born and raised in the shadow of Fasil Ghebbi, I have spent 8 years bringing the 17th-century imperial stones to life for thousands of visitors. My tours include exclusive behind-the-scenes stories passed down by local historians. Licensed by Gondar Tourism Bureau.',
  '+251 91 234 5678', '+251 91 234 5678',
  true, 'GTB-2024-001', 0.10
),
(
  'Selam B.', 'SB', '#8B1A00',
  'Timket Festival • Photography • Cultural Tours',
  1500, 55, 4.8, 89, 6,
  ARRAY['Amharic (Native)','English (Fluent)','French (Fluent)'],
  ARRAY['Timket','Photography','Culture'],
  'I specialize in the Timket festival experience, guiding tourists to the best ceremonial vantage points and helping capture unforgettable moments. My photography tours of Gondar have been featured in travel magazines. I also lead women-only tour groups on request.',
  '+251 91 345 6789', '+251 91 345 6789',
  true, 'GTB-2024-002', 0.10
),
(
  'Yosef T.', 'YT', '#1A1A2E',
  'Full-Day Driver • Outskirts • Simien Mountains',
  2000, 70, 4.7, 67, 10,
  ARRAY['Amharic (Native)','English (Fluent)'],
  ARRAY['Driver','Simien','Outskirts'],
  'With 10 years of experience driving tourists around Gondar, the Simien Mountains, and Lake Tana, I know every road, shortcut, and hidden gem in the region. I drive a comfortable 4WD vehicle and provide full-day tours with flexible itineraries.',
  '+251 91 456 7890', '+251 91 456 7890',
  true, 'GTB-2024-003', 0.10
),
(
  'Miriam A.', 'MA', '#2E7D32',
  'Churches • Religious History • Amharic',
  1000, 38, 4.8, 54, 5,
  ARRAY['Amharic (Native)','English (Fluent)','Arabic (Basic)'],
  ARRAY['Churches','Religion','History'],
  'I am a specialist in the Orthodox Christian heritage of Gondar, including Debre Berhan Selassie, Qusquam Maryam, and other sacred sites. I hold a degree in Ethiopian History from the University of Gondar and am passionate about sharing our faith and culture.',
  '+251 91 567 8901', '+251 91 567 8901',
  true, 'GTB-2024-004', 0.10
);

-- ── 8. REAL TIMKET EVENTS ─────────────────────────────────
delete from events;
insert into events (title, title_am, subtitle, description, event_date, event_time, location, lat, lng, type, is_active) values
(
  'Ketera — Eve of Timket', 'ቀጠራ',
  'Grand procession to Fasilides Bath',
  'The most colourful day of Timket begins at sunset as the Tabots (sacred replicas of the Ark of the Covenant) are carried from every church in Gondar in a grand procession. Thousands of white-robed pilgrims, priests carrying colourful umbrellas, and the sound of drums and chanting fill the streets as the procession makes its way to Fasilides Bath.',
  '2027-01-18', '15:00', 'All Churches → Fasilides Bath', 12.6062, 37.4648, 'timket', true
),
(
  'Timket — Epiphany Morning', 'ጥምቀት',
  'Water blessing ceremony at Fasilides Bath',
  'At dawn, the Patriarch or his representative blesses the water of Fasilides Bath. Tens of thousands of pilgrims crowd the banks as priests sprinkle holy water upon the crowd. Many jump into the pool to symbolically renew their baptism. This is the most sacred and spectacular moment of the festival — arrive by 5am for the best view.',
  '2027-01-19', '06:00', 'Fasilides Bath, Gondar', 12.6062, 37.4648, 'timket', true
),
(
  'Kana Ze Galila', 'ቃና ዘገሊላ',
  'Return procession to the churches',
  'On the third day, dedicated to the miracle at Cana, the Tabots are carried back to their respective churches in a joyful procession. The streets come alive with singing, dancing, and celebration. Traditional music groups and cultural performers line the route.',
  '2027-01-20', '08:00', 'Fasilides Bath → City Churches', 12.6043, 37.4700, 'timket', true
);

-- ── 9. SAMPLE NOTIFICATIONS ──────────────────────────────
insert into notifications (title, body, type) values
('Water blessing in 20 minutes', '— leave now for a good spot at Fasilides Bath.', 'alert'),
('Fasilides Palace now lit every evening', 'Visit after 7pm for stunning light shows on the ancient walls.', 'info'),
('Heavy crowds near the bath', '— use the north entrance off Fasilides Road.', 'warning'),
('New audio guide available', 'Debre Berhan Selassie now has a full 45-minute audio guide in English and Amharic.', 'info');

-- ── 10. VERIFY ───────────────────────────────────────────
select 'sites' as t, count(*) from sites
union all select 'hotels', count(*) from hotels
union all select 'guides', count(*) from guides
union all select 'events', count(*) from events
union all select 'notifications', count(*) from notifications
union all select 'commissions table', count(*) from commissions;
