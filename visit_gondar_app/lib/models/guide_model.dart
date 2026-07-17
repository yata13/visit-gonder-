class GuideModel {
  final String id;
  final String name;
  final String initials;
  final String avatarColor;    // hex color string e.g. '#F4BE56'
  final String avatarUrl;
  final String specialties;
  final double pricePerDay;    // in ETB
  final double priceUSD;
  final double rating;
  final int reviewCount;
  final int yearsExperience;
  final List<String> languages;
  final List<String> tags;     // ['History', 'Timket', 'Photography']
  final String about;
  final bool isVerified;
  final DateTime createdAt;

  const GuideModel({
    required this.id,
    required this.name,
    required this.initials,
    required this.avatarColor,
    required this.avatarUrl,
    required this.specialties,
    required this.pricePerDay,
    required this.priceUSD,
    required this.rating,
    required this.reviewCount,
    required this.yearsExperience,
    required this.languages,
    required this.tags,
    required this.about,
    required this.isVerified,
    required this.createdAt,
  });

  factory GuideModel.fromJson(Map<String, dynamic> json) => GuideModel(
    id:               json['id'] as String,
    name:             json['name'] as String,
    initials:         json['initials'] as String,
    avatarColor:      json['avatar_color'] as String,
    avatarUrl:        json['avatar_url'] as String? ?? '',
    specialties:      json['specialties'] as String,
    pricePerDay:      (json['price_per_day'] as num).toDouble(),
    priceUSD:         (json['price_usd'] as num).toDouble(),
    rating:           (json['rating'] as num).toDouble(),
    reviewCount:      json['review_count'] as int,
    yearsExperience:  json['years_experience'] as int,
    languages:        List<String>.from(json['languages'] as List),
    tags:             List<String>.from(json['tags'] as List),
    about:            json['about'] as String,
    isVerified:       json['is_verified'] as bool,
    createdAt:        DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id':               id,
    'name':             name,
    'initials':         initials,
    'avatar_color':     avatarColor,
    'avatar_url':       avatarUrl,
    'specialties':      specialties,
    'price_per_day':    pricePerDay,
    'price_usd':        priceUSD,
    'rating':           rating,
    'review_count':     reviewCount,
    'years_experience': yearsExperience,
    'languages':        languages,
    'tags':             tags,
    'about':            about,
    'is_verified':      isVerified,
  };
}
