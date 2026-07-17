class SiteModel {
  final String id;
  final String name;
  final String subtitle;
  final String description;
  final String location;
  final double rating;
  final int reviewCount;
  final String imageUrl;
  final String category;       // 'Castles' | 'Churches' | 'Timket'
  final bool hasAudioGuide;
  final double? distanceKm;
  final double? lat;
  final double? lng;
  final DateTime createdAt;

  const SiteModel({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.location,
    required this.rating,
    required this.reviewCount,
    required this.imageUrl,
    required this.category,
    required this.hasAudioGuide,
    this.distanceKm,
    this.lat,
    this.lng,
    required this.createdAt,
  });

  // Convert from Supabase JSON row → SiteModel
  factory SiteModel.fromJson(Map<String, dynamic> json) => SiteModel(
    id:            json['id'] as String,
    name:          json['name'] as String,
    subtitle:      json['subtitle'] as String,
    description:   json['description'] as String,
    location:      json['location'] as String,
    rating:        (json['rating'] as num).toDouble(),
    reviewCount:   json['review_count'] as int,
    imageUrl:      json['image_url'] as String,
    category:      json['category'] as String,
    hasAudioGuide: json['has_audio_guide'] as bool,
    distanceKm:    (json['distance_km'] as num?)?.toDouble(),
    lat:           (json['lat'] as num?)?.toDouble(),
    lng:           (json['lng'] as num?)?.toDouble(),
    createdAt:     DateTime.parse(json['created_at'] as String),
  );

  // Convert SiteModel → JSON (for inserting/updating)
  Map<String, dynamic> toJson() => {
    'id':              id,
    'name':            name,
    'subtitle':        subtitle,
    'description':     description,
    'location':        location,
    'rating':          rating,
    'review_count':    reviewCount,
    'image_url':       imageUrl,
    'category':        category,
    'has_audio_guide': hasAudioGuide,
    'distance_km':     distanceKm,
    'lat':             lat,
    'lng':             lng,
  };
}
