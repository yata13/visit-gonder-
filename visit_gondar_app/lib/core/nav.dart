// One place for "open this thing" so every screen behaves the same.
import 'package:flutter/material.dart';
import '../providers/data_providers.dart';
import '../providers/language_provider.dart';
import '../screens/sites/site_detail_screen.dart';
import '../screens/hotels/hotels_screen.dart';
import '../screens/guides/guide_profile_screen.dart';
import '../screens/timket/timket_roadmap.dart';
import '../widgets/ui.dart';

void openSite(BuildContext context, Map<String, dynamic> site, String lang) =>
    pushScreen(context, SiteDetailScreen(site: {
      'id': site['id'],
      'name': localName(site, lang),
      'subtitle': (site['info'] ?? '') as String,
      'location': (site['location'] ?? '') as String,
      'image': sitePhoto(site),
      'description': (site['description'] ?? '') as String,
      'rating': '4.8',
      'tag': '',
      'audio': false,
    }));

void openHotel(BuildContext context, Map<String, dynamic> hotel) =>
    pushScreen(context, HotelDetailPage(hotel: hotel));

void openGuide(BuildContext context, Map<String, dynamic> guide) =>
    pushScreen(context, GuideProfileScreen(guide: guide));

void openEvent(BuildContext context, Map<String, dynamic> event,
    String lang) {
  if (event['includes_timket'] == true) {
    pushScreen(context, TimketRoadmapScreen(lang: lang));
    return;
  }
  final name = (event['name'] ?? '') as String;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(isAm(lang)
        ? '$name — በቅርቡ ይመጣል'
        : '$name — full guide coming soon'),
  ));
}
