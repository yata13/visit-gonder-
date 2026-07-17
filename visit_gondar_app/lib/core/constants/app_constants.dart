// App-wide constants — one place to change everything

class AppConstants {
  // App info
  static const appName     = 'Visit Gondar';
  static const appVersion  = '1.0.0';

  // Timket festival date (Jan 19 every year)
  static final timketDate  = DateTime(DateTime.now().year + 1, 1, 19);

  // Supabase table names
  static const tableSites         = 'sites';
  static const tableHotels        = 'hotels';
  static const tableGuides        = 'guides';
  static const tableBookings      = 'bookings';
  static const tableEvents        = 'events';
  static const tableNotifications = 'notifications';
  static const tableReviews       = 'reviews';
  static const tableUsers         = 'users';

  // Supabase storage buckets
  static const bucketSiteImages  = 'site-images';
  static const bucketHotelImages = 'hotel-images';
  static const bucketGuideImages = 'guide-images';

  // Supported languages
  static const langEnglish = 'en';
  static const langAmharic = 'am';

  // SharedPreferences keys
  static const prefLanguage       = 'language';
  static const prefOnboardingDone = 'onboarding_done';
  static const prefMyContact      = 'my_contact';

  // ── Onboarding / intro images ─────────────────────────────
  //  ONE place to change every first-open picture. Paste a public
  //  image URL (e.g. a Supabase Storage public link) between the
  //  quotes to swap any of these out.
  //
  //  👉 onboardingCover  = the big "Welcome to Gondar" cover image.
  //     Replace it with your own paper-cut artwork URL.
  //  For each image below you can paste EITHER a web URL
  //  ('https://....jpg') OR a local file ('assets/images/yourfile.png').
  //  Drop local files into the assets/images/ folder first.
  static const onboardingCover =
      'assets/images/cover.png';
  static const introImage1 =
      'https://i.postimg.cc/5tX5psJj/686ec2e0e3a95f0e10c9f5c998a9503d.jpg';
  static const introImage2 =
      'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800&q=80';
  static const introImage3 =
      'https://i.postimg.cc/9XD3Zhsw/39926cec947327694bdfd2e58ec1bcae.webp';
}
