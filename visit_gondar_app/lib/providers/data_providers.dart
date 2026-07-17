import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live data streams — the SAME tables the admin dashboard manages.
/// Supabase realtime streams mean admin edits appear here instantly.

final hotelsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return Supabase.instance.client
      .from('hotels')
      .stream(primaryKey: ['id'])
      .order('price', ascending: false)
      .map((rows) => rows
          .where((h) => (h['publish_status'] ?? 'published') == 'published')
          .toList());
});

final sitesProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return Supabase.instance.client
      .from('sites')
      .stream(primaryKey: ['id'])
      .order('created_at')
      .map((rows) => rows.toList());
});

final guidesProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return Supabase.instance.client
      .from('guides')
      .stream(primaryKey: ['id'])
      .order('price', ascending: false)
      .map((rows) => rows
          .where((g) => (g['publish_status'] ?? 'published') == 'published')
          .toList());
});

final eventsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return Supabase.instance.client
      .from('events')
      .stream(primaryKey: ['id'])
      .order('created_at')
      .map((rows) => rows.toList());
});

/// Map places — fully managed by the admin "Map Manager" tab.
/// Categories: hotel, castle, church, museum, store, club,
/// restaurant, other.
final placesProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return Supabase.instance.client
      .from('places')
      .stream(primaryKey: ['id'])
      .order('created_at')
      .map((rows) => rows.toList());
});

/// Gondar news feed — posts written in the admin "News Feed" tab.
/// Newest first; realtime, so a new post appears instantly.
final postsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return Supabase.instance.client
      .from('posts')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.toList());
});

/// Best Timket photo from live data: a Timket event's photo first,
/// then the Fasilides Bath site, then any site photo.
String timketPhotoFrom(List<Map<String, dynamic>> events,
    List<Map<String, dynamic>> sites) {
  for (final e in events) {
    final p = (e['photo'] ?? '') as String;
    if (e['includes_timket'] == true && p.isNotEmpty) return p;
  }
  for (final s in sites) {
    final name = ((s['name_en'] ?? '') as String).toLowerCase();
    final p = (s['photo'] ?? '') as String;
    if (name.contains('bath') && p.isNotEmpty) return p;
  }
  for (final s in sites) {
    final p = (s['photo'] ?? '') as String;
    if (p.isNotEmpty) return p;
  }
  return '';
}

// ── Helpers to read live-schema rows safely ───────────────────
String hotelName(Map<String, dynamic> h) =>
    (h['name_en'] ?? h['name'] ?? '') as String;

String hotelPhoto(Map<String, dynamic> h) {
  final photos = h['photos'];
  if (photos is List && photos.isNotEmpty) return photos.first.toString();
  return '';
}

double hotelPrice(Map<String, dynamic> h) =>
    ((h['price'] ?? 0) as num).toDouble();

int hotelStars(Map<String, dynamic> h) =>
    ((h['star_ranking'] ?? 4) as num).toInt();

String siteName(Map<String, dynamic> s) =>
    (s['name_en'] ?? s['name'] ?? '') as String;

String sitePhoto(Map<String, dynamic> s) => (s['photo'] ?? '') as String;
