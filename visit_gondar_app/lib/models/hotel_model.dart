class HotelModel {
  final String id;
  final String name;
  final String subtitle;
  final double pricePerNight;
  final double rating;
  final int reviewCount;
  final String imageUrl;
  final String tag;            // 'Top rated' | 'Luxury' | 'Mid-range' | 'Budget'
  final List<String> amenities;
  final double distanceKm;
  final double? lat;
  final double? lng;
  final DateTime createdAt;

  const HotelModel({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.pricePerNight,
    required this.rating,
    required this.reviewCount,
    required this.imageUrl,
    required this.tag,
    required this.amenities,
    required this.distanceKm,
    this.lat,
    this.lng,
    required this.createdAt,
  });

  factory HotelModel.fromJson(Map<String, dynamic> json) => HotelModel(
    id:             json['id'] as String,
    name:           json['name'] as String,
    subtitle:       json['subtitle'] as String,
    pricePerNight:  (json['price_per_night'] as num).toDouble(),
    rating:         (json['rating'] as num).toDouble(),
    reviewCount:    json['review_count'] as int,
    imageUrl:       json['image_url'] as String,
    tag:            json['tag'] as String,
    amenities:      List<String>.from(json['amenities'] as List),
    distanceKm:     (json['distance_km'] as num).toDouble(),
    lat:            (json['lat'] as num?)?.toDouble(),
    lng:            (json['lng'] as num?)?.toDouble(),
    createdAt:      DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id':               id,
    'name':             name,
    'subtitle':         subtitle,
    'price_per_night':  pricePerNight,
    'rating':           rating,
    'review_count':     reviewCount,
    'image_url':        imageUrl,
    'tag':              tag,
    'amenities':        amenities,
    'distance_km':      distanceKm,
    'lat':              lat,
    'lng':              lng,
  };
}
