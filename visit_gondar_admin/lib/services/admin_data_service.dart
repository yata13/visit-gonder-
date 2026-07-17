// ═══════════════════════════════════════════════════════════════
//  Admin data layer — models + CRUD for every admin tab.
//  The fromJson factories accept BOTH old and new column names
//  (e.g. `name_en` or `name`, `price` or `price_per_night`) so the
//  dashboard keeps working while the database schema evolves.
// ═══════════════════════════════════════════════════════════════
import 'admin_supabase.dart';

// ── Models ────────────────────────────────────────────────────
class AdminHotel {
  final String id;
  final String nameEn, nameAm, description, location, contact, publishStatus;
  final List<String> photos;
  final double price;
  final int starRanking;

  AdminHotel({
    required this.id, required this.nameEn, required this.nameAm,
    required this.description, required this.location, required this.contact,
    required this.publishStatus, required this.photos,
    required this.price, required this.starRanking,
  });

  factory AdminHotel.fromJson(Map<String, dynamic> j) => AdminHotel(
    id: j['id']?.toString() ?? '',
    nameEn: j['name_en'] ?? j['name'] ?? '',
    nameAm: j['name_am'] ?? '',
    description: j['description'] ?? '',
    location: j['location'] ?? '',
    contact: j['contact'] ?? j['phone'] ?? '',
    publishStatus: j['publish_status'] ?? (j['is_active'] == true ? 'published' : 'hidden'),
    photos: j['photos'] != null
        ? List<String>.from(j['photos'])
        : (j['image_url'] != null ? [j['image_url']] : []),
    price: (j['price'] ?? j['price_per_night'] ?? 0).toDouble(),
    starRanking: (j['star_ranking'] ?? j['rating'] ?? 4).toInt(),
  );

  Map<String, dynamic> toJson() => {
    'name_en': nameEn, 'name_am': nameAm,
    'description': description, 'location': location,
    'contact': contact, 'publish_status': publishStatus,
    'photos': photos, 'price': price, 'star_ranking': starRanking,
  };
}

class AdminGuide {
  final String id, name, specialty, photo, licenseStatus, publishStatus;
  final List<String> languages;
  final double price;

  AdminGuide({
    required this.id, required this.name, required this.specialty,
    required this.photo, required this.licenseStatus, required this.publishStatus,
    required this.languages, required this.price,
  });

  factory AdminGuide.fromJson(Map<String, dynamic> j) => AdminGuide(
    id: j['id']?.toString() ?? '',
    name: j['name'] ?? '',
    specialty: j['specialty'] ?? j['specialties'] ?? '',
    photo: j['photo'] ?? j['avatar_url'] ?? '',
    licenseStatus: j['license_status'] ?? (j['is_verified'] == true ? 'licensed' : 'unlicensed'),
    publishStatus: j['publish_status'] ?? 'published',
    languages: j['languages'] != null ? List<String>.from(j['languages']) : ['English'],
    price: (j['price'] ?? j['price_per_day'] ?? 0).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'initials': name.trim().isNotEmpty
        ? name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : 'GD',
    'specialty': specialty, 'photo': photo,
    'license_status': licenseStatus, 'publish_status': publishStatus,
    'languages': languages, 'price': price,
  };
}

class AdminSite {
  final String id, nameEn, nameAm, description, info, location, photo;

  AdminSite({
    required this.id, required this.nameEn, required this.nameAm,
    required this.description, required this.info,
    required this.location, required this.photo,
  });

  factory AdminSite.fromJson(Map<String, dynamic> j) => AdminSite(
    id: j['id']?.toString() ?? '',
    nameEn: j['name_en'] ?? j['name'] ?? '',
    nameAm: j['name_am'] ?? '',
    description: j['description'] ?? '',
    info: j['info'] ?? j['subtitle'] ?? '',
    location: j['location'] ?? '',
    photo: j['photo'] ?? j['image_url'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'name_en': nameEn, 'name_am': nameAm, 'description': description,
    'info': info, 'location': location, 'photo': photo,
  };
}

class AdminEvent {
  final String id, name, date, description, photo, category;
  final bool includesTimket;

  AdminEvent({
    required this.id, required this.name, required this.date,
    required this.description, required this.photo, required this.category,
    required this.includesTimket,
  });

  factory AdminEvent.fromJson(Map<String, dynamic> j) => AdminEvent(
    id: j['id']?.toString() ?? '',
    name: j['name'] ?? j['title'] ?? '',
    date: j['date'] ?? j['event_date'] ?? '',
    description: j['description'] ?? '',
    photo: j['photo'] ?? j['image_url'] ?? '',
    category: j['category'] ?? 'Religious Festival',
    includesTimket: j['includes_timket'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'name': name, 'date': date, 'description': description,
    'photo': photo, 'category': category, 'includes_timket': includesTimket,
  };
}

class AdminNotification {
  final String id, title, type, message, createdAt;
  final bool sendToAll;

  AdminNotification({
    required this.id, required this.title, required this.type,
    required this.message, required this.createdAt, required this.sendToAll,
  });

  factory AdminNotification.fromJson(Map<String, dynamic> j) => AdminNotification(
    id: j['id']?.toString() ?? '',
    title: j['title'] ?? '',
    type: j['type'] ?? 'news',
    message: j['message'] ?? j['body'] ?? '',
    createdAt: j['created_at'] ?? DateTime.now().toIso8601String(),
    sendToAll: j['send_to_all'] ?? true,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'type': type,
    'message': message,
    'body': message,
    'send_to_all': sendToAll,
  };
}

class AdminBooking {
  final String id, itemType, itemName, customerName, customerContact, bookingDate, status;
  final double price, commissionEarned;

  AdminBooking({
    required this.id, required this.itemType, required this.itemName,
    required this.customerName, required this.customerContact,
    required this.bookingDate, required this.status,
    required this.price, required this.commissionEarned,
  });

  factory AdminBooking.fromJson(Map<String, dynamic> j) => AdminBooking(
    id: j['id']?.toString() ?? '',
    itemType: j['item_type'] ?? 'hotel',
    itemName: j['item_name'] ?? '',
    customerName: j['customer_name'] ?? '',
    customerContact: j['customer_contact'] ?? '',
    bookingDate: j['booking_date'] ?? j['created_at'] ?? '',
    status: j['status'] ?? 'pending',
    price: (j['price'] ?? j['total_amount'] ?? 0).toDouble(),
    commissionEarned: (j['commission_earned'] ?? j['commission_amount'] ?? 0).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'item_type': itemType, 'item_name': itemName,
    'customer_name': customerName, 'customer_contact': customerContact,
    'booking_date': bookingDate, 'status': status,
    'price': price, 'commission_earned': commissionEarned,
  };
}

// ── Service ───────────────────────────────────────────────────
class AdminDataService {
  static final db = AdminSupabase.db;

  // Helper: insert (no id) vs update (with id)
  static Future<void> _save(String table, String id, Map<String, dynamic> json) async {
    if (id.isEmpty) {
      // New record — let Supabase generate UUID
      await db.from(table).insert(json);
    } else {
      // Existing record — update by id
      await db.from(table).update(json).eq('id', id);
    }
  }

  // ── Hotels ──────────────────────────────────────────────────
  static Future<List<AdminHotel>> getHotels() async {
    try {
      final data = await db.from('hotels').select();
      return (data as List).map((e) => AdminHotel.fromJson(e)).toList();
    } catch (_) { return []; }
  }

  static Future<void> saveHotel(AdminHotel h) async =>
      _save('hotels', h.id, h.toJson());

  static Future<void> deleteHotel(String id) async =>
      db.from('hotels').delete().eq('id', id);

  // ── Guides ──────────────────────────────────────────────────
  static Future<List<AdminGuide>> getGuides() async {
    try {
      final data = await db.from('guides').select();
      return (data as List).map((e) => AdminGuide.fromJson(e)).toList();
    } catch (_) { return []; }
  }

  static Future<void> saveGuide(AdminGuide g) async =>
      _save('guides', g.id, g.toJson());

  static Future<void> deleteGuide(String id) async =>
      db.from('guides').delete().eq('id', id);

  // ── Sites ───────────────────────────────────────────────────
  static Future<List<AdminSite>> getSites() async {
    try {
      final data = await db.from('sites').select();
      return (data as List).map((e) => AdminSite.fromJson(e)).toList();
    } catch (_) { return []; }
  }

  static Future<void> saveSite(AdminSite s) async =>
      _save('sites', s.id, s.toJson());

  static Future<void> deleteSite(String id) async =>
      db.from('sites').delete().eq('id', id);

  // ── Events ──────────────────────────────────────────────────
  static Future<List<AdminEvent>> getEvents() async {
    try {
      final data = await db.from('events').select();
      return (data as List).map((e) => AdminEvent.fromJson(e)).toList();
    } catch (_) { return []; }
  }

  static Future<void> saveEvent(AdminEvent e) async =>
      _save('events', e.id, e.toJson());

  static Future<void> deleteEvent(String id) async =>
      db.from('events').delete().eq('id', id);

  // ── Notifications ────────────────────────────────────────────
  static Future<List<AdminNotification>> getNotifications() async {
    try {
      final data = await db.from('notifications').select()
          .order('created_at', ascending: false);
      return (data as List).map((e) => AdminNotification.fromJson(e)).toList();
    } catch (_) { return []; }
  }

  static Future<void> saveNotification(AdminNotification n) async =>
      db.from('notifications').insert(n.toJson());

  static Future<void> deleteNotification(String id) async =>
      db.from('notifications').delete().eq('id', id);

  // ── Bookings ─────────────────────────────────────────────────
  static Future<List<AdminBooking>> getBookings() async {
    try {
      final data = await db.from('bookings').select()
          .order('created_at', ascending: false);
      return (data as List).map((e) => AdminBooking.fromJson(e)).toList();
    } catch (_) { return []; }
  }

  static Future<void> updateBookingStatus(String id, String status) async =>
      db.from('bookings').update({'status': status}).eq('id', id);
}
