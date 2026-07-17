import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

/// App language: 'en' or 'am'. Persisted across restarts.
final languageProvider =
    StateNotifierProvider<LanguageController, String>(
        (ref) => LanguageController());

class LanguageController extends StateNotifier<String> {
  LanguageController() : super(AppConstants.langEnglish) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConstants.prefLanguage);
    if (saved != null) state = saved;
  }

  Future<void> toggle() async {
    state = state == AppConstants.langEnglish
        ? AppConstants.langAmharic
        : AppConstants.langEnglish;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefLanguage, state);
  }
}

bool isAm(String lang) => lang == AppConstants.langAmharic;

/// UI strings — English / Amharic.
const Map<String, Map<String, String>> _t = {
  'discover': {'en': 'Discover\n', 'am': 'ያግኙ\n'},
  'camelot': {'en': 'Gondar', 'am': 'ጎንደር'},
  'search_hint': {
    'en': 'Search sites, hotels, guides…',
    'am': 'ቦታዎች፣ ሆቴሎች፣ መመሪያዎች ይፈልጉ…'
  },
  'sites': {'en': 'Sites', 'am': 'ቦታዎች'},
  'hotels': {'en': 'Hotels', 'am': 'ሆቴሎች'},
  'guides': {'en': 'Guides', 'am': 'መመሪያዎች'},
  'map': {'en': 'Map', 'am': 'ካርታ'},
  'must_see': {'en': 'Must-see sites', 'am': 'መታየት ያለባቸው ቦታዎች'},
  'top_hotels': {'en': 'Top hotels', 'am': 'ምርጥ ሆቴሎች'},
  'view_all': {'en': 'View all', 'am': 'ሁሉንም ይመልከቱ'},
  'featured': {'en': 'FEATURED', 'am': 'ተመራጭ'},
  'explore': {'en': 'Explore', 'am': 'ይጎብኙ'},
  'timket_title': {'en': 'Timket Festival', 'am': 'የጥምቀት በዓል'},
  'timket_sub': {
    'en': 'The greatest Epiphany celebration in Ethiopia',
    'am': 'በኢትዮጵያ ታላቁ የጥምቀት በዓል'
  },
  'days': {'en': 'DAYS', 'am': 'ቀናት'},
  'hrs': {'en': 'HRS', 'am': 'ሰዓት'},
  'min': {'en': 'MIN', 'am': 'ደቂቃ'},
  'offline_ready': {
    'en': 'Offline Mode Ready — guides available without internet',
    'am': 'ከመስመር ውጪ ዝግጁ — መመሪያዎች ያለ ኢንተርኔት ይገኛሉ'
  },
  'results': {'en': 'results', 'am': 'ውጤቶች'},
  'result': {'en': 'result', 'am': 'ውጤት'},
  'historic_sites': {'en': 'HISTORIC SITES', 'am': 'ታሪካዊ ቦታዎች'},
  'local_guides': {'en': 'LOCAL GUIDES', 'am': 'የአካባቢ መመሪያዎች'},
  'hotels_label': {'en': 'HOTELS', 'am': 'ሆቴሎች'},
  'no_match': {'en': 'No matches for', 'am': 'ምንም አልተገኘም ለ'},
  'try_other': {
    'en': 'Try a different name in English or Amharic',
    'am': 'በእንግሊዝኛ ወይም በአማርኛ ሌላ ስም ይሞክሩ'
  },
  'no_sites': {
    'en': 'No sites yet — add them in the admin',
    'am': 'እስካሁን ቦታ የለም — በአስተዳዳሪው ያክሉ'
  },
  'no_hotels': {
    'en': 'No hotels yet — add them in the admin',
    'am': 'እስካሁን ሆቴል የለም — በአስተዳዳሪው ያክሉ'
  },
  'per_night': {'en': '/night', 'am': '/ሌሊት'},
  'per_day': {'en': '/day', 'am': '/ቀን'},
  'gondar_today': {'en': 'Gondar Today', 'am': 'ጎንደር ዛሬ'},
  'read_more': {'en': 'Read more', 'am': 'ተጨማሪ ያንብቡ'},
  // Screen titles & subtitles
  'sites_title': {'en': 'Historic Sites', 'am': 'ታሪካዊ ቦታዎች'},
  'sites_sub': {
    'en': 'Explore the legacy of the Gondar Empire',
    'am': 'የጎንደር መንግሥት ቅርስ ይጎብኙ'
  },
  'hotels_title': {'en': 'Hotels & Lodges', 'am': 'ሆቴሎችና ማረፊያዎች'},
  'live_db': {
    'en': 'Live from the Visit Gondar database',
    'am': 'በቀጥታ ከጎንደር ጉብኝት መረጃ ቋት'
  },
  'guides_title': {'en': 'Local Guides', 'am': 'የአካባቢ መመሪያዎች'},
  'guides_sub': {
    'en': 'Licensed guides, verified by the tourism bureau',
    'am': 'በቱሪዝም ቢሮ የተረጋገጡ ፈቃድ ያላቸው መመሪያዎች'
  },
  // Buttons
  'view_book': {'en': 'View & Book', 'am': 'ይመልከቱ እና ይያዙ'},
  'book_now': {'en': 'Book Now', 'am': 'አሁን ይያዙ'},
  'book_guide': {'en': 'Book This Guide', 'am': 'ይህን መመሪያ ይያዙ'},
  'about': {'en': 'About', 'am': 'ስለ ቦታው'},
  'gallery': {'en': 'Gallery', 'am': 'ምስሎች'},
  'per_night_label': {'en': 'Per night', 'am': 'በሌሊት'},
  // Empty states
  'no_sites_title': {'en': 'No sites yet', 'am': 'እስካሁን ቦታ የለም'},
  'no_hotels_title': {'en': 'No hotels yet', 'am': 'እስካሁን ሆቴል የለም'},
  'no_guides_title': {'en': 'No guides yet', 'am': 'እስካሁን መመሪያ የለም'},
  'admin_appear': {
    'en': 'Items added in the admin dashboard appear here',
    'am': 'በአስተዳዳሪው የተጨመሩት እዚህ ይታያሉ'
  },
  // Bottom navigation
  'nav_home': {'en': 'Home', 'am': 'መነሻ'},
  'nav_sites': {'en': 'Sites', 'am': 'ቦታዎች'},
  'nav_timket': {'en': 'Timket', 'am': 'ጥምቀት'},
  'nav_sos': {'en': 'SOS', 'am': 'አደጋ'},
  'nav_map': {'en': 'Map', 'am': 'ካርታ'},
  'nav_stay': {'en': 'Stay', 'am': 'ማረፊያ'},
};

/// Localized post fields (title/body have *_am columns).
String postField(Map<String, dynamic> p, String field, String lang) {
  if (isAm(lang)) {
    final am = (p['${field}_am'] ?? '') as String;
    if (am.isNotEmpty) return am;
  }
  return (p[field] ?? '') as String;
}

String tr(String lang, String key) =>
    _t[key]?[lang] ?? _t[key]?['en'] ?? key;

/// Localized content names from live rows (DB has name_en / name_am).
String localName(Map<String, dynamic> row, String lang) {
  if (isAm(lang)) {
    final am = (row['name_am'] ?? '') as String;
    if (am.isNotEmpty) return am;
  }
  return (row['name_en'] ?? row['name'] ?? '') as String;
}
