import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/data_providers.dart';
import '../../providers/language_provider.dart';
import '../../providers/tier_provider.dart';
import '../../widgets/shimmer_image.dart';
import '../../widgets/ui.dart';
import '../../widgets/panorama_360.dart';
import '../../core/constants/app_constants.dart';
import '../ai/ask_gondar_screen.dart';
import '../premium/premium_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  VIRTUAL TOUR — Fasil Ghebbi (Premium).
//  A guided walk through the royal compound, one stop per page.
//  Photos come from the live `sites` / `places` tables: a stop uses
//  the photo of the row whose English name matches one of its
//  keywords, else the Fasil Ghebbi photo. Add a site called e.g.
//  "Iyasu Palace" with a photo in the admin and that stop picks it up.
// ═══════════════════════════════════════════════════════════════
class _Stop {
  final String titleEn, titleAm, bodyEn, bodyAm;
  final List<String> keywords;
  final IconData icon;
  const _Stop(this.titleEn, this.titleAm, this.bodyEn, this.bodyAm,
      this.keywords, this.icon);
}

/// 360° picture of the compound — set in AppConstants.tourPanorama
/// (a painted demo until a real 360° photo of Fasil Ghebbi is added).
const _panorama = AppConstants.tourPanorama;

/// Where to face first for each stop (0..1 of the way round the
/// picture). With the castle-ruin photo every stop opens on its
/// great arch, then turns a little so each stop feels different.
const _panoramaHeadings = [0.5, 0.42, 0.58, 0.35, 0.65, 0.28, 0.5];

const _stops = [
  _Stop(
    'The royal compound', 'የነገሥታት ግቢ',
    'Fasil Ghebbi is the walled royal enclosure of Gondar. Its wall, about '
        '900 metres long with twelve gates, surrounds the castles and halls '
        'built by the emperors from the 1600s. It has been a UNESCO World '
        'Heritage Site since 1979.',
    'ፋሲል ግቢ በግንብ የታጠረ የጎንደር የነገሥታት ግቢ ነው። ወደ 900 ሜትር የሚረዝመው '
        'አሥራ ሁለት በሮች ያሉት ግንብ ከ17ኛው ክፍለ ዘመን ጀምሮ በነገሥታቱ የተሠሩ '
        'ቤተ መንግሥታትን ይከባል። ከ1979 እ.ኤ.አ. ጀምሮ የዩኔስኮ የዓለም ቅርስ ነው።',
    ['ghebbi', 'gebbi', 'royal enclosure', 'fasil'],
    Icons.fort_outlined,
  ),
  _Stop(
    "Emperor Fasilides' Castle", 'የአፄ ፋሲለደስ ቤተ መንግሥት',
    'The oldest and grandest castle, built for Emperor Fasilides, who made '
        'Gondar his capital in 1636. Look up at the round corner towers and '
        'domes, and the stone and lime walls that have stood for almost '
        '400 years.',
    'ጎንደርን በ1636 እ.ኤ.አ. ዋና ከተማ ያደረጉት የአፄ ፋሲለደስ ቤተ መንግሥት — '
        'የግቢው ጥንታዊና ትልቁ ሕንፃ። ክብ የማዕዘን ማማዎቹን እና ጉልላቶቹን፣ '
        'ለ400 ዓመታት የቆሙትን የድንጋይና የኖራ ግድግዳዎች ይመልከቱ።',
    ['fasilides castle', 'fasil castle', 'fasiladas'],
    Icons.castle_outlined,
  ),
  _Stop(
    'Library and Chancellery', 'ቤተ መጻሕፍትና ጽሕፈት ቤት',
    'Built in the time of Emperor Yohannes I, the son of Fasilides. Books '
        'and the business of the court were kept here, close to the '
        'emperor’s castle.',
    'በአፄ ፋሲለደስ ልጅ በአፄ ዮሐንስ ቀዳማዊ ዘመን የተሠሩ። የቤተ መንግሥቱ መጻሕፍትና '
        'የአስተዳደር ሥራ እዚህ ይካሄድ ነበር።',
    ['library', 'yohannes', 'chancellery'],
    Icons.menu_book_outlined,
  ),
  _Stop(
    "Iyasu I's Palace", 'የአፄ ኢያሱ ቀዳማዊ ቤተ መንግሥት',
    'Emperor Iyasu I, the grandson of Fasilides, built this palace. It was '
        'once famous for its rich decoration. Today it stands without its '
        'roof, but the size of its walls still shows its glory.',
    'የአፄ ፋሲለደስ የልጅ ልጅ አፄ ኢያሱ ቀዳማዊ ያሠሩት ቤተ መንግሥት። በአንድ ወቅት '
        'በውብ ጌጡ ይታወቅ ነበር። ዛሬ ጣሪያ የለውም፣ ግን የግድግዳዎቹ ግዝፈት '
        'ታላቅነቱን ይመሰክራል።',
    ['iyasu'],
    Icons.account_balance_outlined,
  ),
  _Stop(
    "Dawit III's Hall and the lion house", 'የአፄ ዳዊት ሣልሳዊ አዳራሽና የአንበሶች ቤት',
    'A hall for music and celebrations, built for Emperor Dawit III. '
        'Nearby are the old lion cages, where Abyssinian lions — a royal '
        'symbol — were kept until the 1990s.',
    'ለአፄ ዳዊት ሣልሳዊ የተሠራ የሙዚቃና የበዓል አዳራሽ። በአቅራቢያው የንጉሣዊ ምልክት '
        'የሆኑት የኢትዮጵያ አንበሶች እስከ 1990ዎቹ የሚቀመጡባቸው የቀድሞ ጎጆዎች አሉ።',
    ['dawit', 'lion'],
    Icons.music_note_outlined,
  ),
  _Stop(
    "Empress Mentewab's Castle", 'የእቴጌ ምንትዋብ ቤተ መንግሥት',
    'Empress Mentewab, one of the most powerful rulers of 18th-century '
        'Gondar, built this two-storey castle. She also founded the Kuskuam '
        'church on the hill outside the city.',
    'በ18ኛው ክፍለ ዘመን ከጎንደር ኃያላን ገዥዎች አንዷ የሆኑት እቴጌ ምንትዋብ ያሠሩት '
        'ባለ ሁለት ፎቅ ቤተ መንግሥት። ከከተማው ውጭ ባለው ኮረብታ ላይ የቁስቋምን '
        'ቤተ ክርስቲያንም መሠረቱ።',
    ['mentewab', 'mentuab'],
    Icons.castle_outlined,
  ),
  _Stop(
    "Next: Fasilides' Bath", 'ቀጣይ፦ የፋሲለደስ መዋኛ',
    'Two kilometres from the compound is Fasilides’ Bath, a small castle in '
        'a large pool. Every January it is filled with water for Timket, '
        'the Epiphany festival, and thousands come to be blessed.',
    'ከግቢው ሁለት ኪሎ ሜትር ርቆ የፋሲለደስ መዋኛ አለ — በትልቅ ገንዳ መካከል ያለ '
        'ትንሽ ቤተ መንግሥት። በየጥሩ ለጥምቀት በዓል በውሃ ይሞላል፣ በሺዎች '
        'የሚቆጠሩ ለበረከት ይመጣሉ።',
    ['bath', 'timket'],
    Icons.water_outlined,
  ),
];

class VirtualTourScreen extends ConsumerWidget {
  const VirtualTourScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final am = isAm(ref.watch(languageProvider));
    final tier = ref.watch(userTierProvider);

    return tier.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (_, _) => _Locked(am: am),
      data: (t) => t.isPremium ? const _Tour() : _Locked(am: am),
    );
  }
}

// ── Free users: what the tour is + how to get Premium ───────────
class _Locked extends StatelessWidget {
  final bool am;
  const _Locked({required this.am});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(am ? 'ምናባዊ ጉብኝት' : 'Virtual tour')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        children: [
          Container(
            height: 180,
            decoration: AppDecor.night(radius: AppRadius.hero),
            alignment: Alignment.center,
            child: const Icon(Icons.threesixty_rounded,
                size: 72, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(am ? 'የፋሲል ግቢ ምናባዊ ጉብኝት' : 'Fasil Ghebbi virtual tour',
              style: const TextStyle(fontSize: 26,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
              am
                  ? 'በ${_stops.length} ቦታዎች በነገሥታቱ ግቢ ውስጥ ይጓዙ — ከቤትዎ ሆነው።'
                  : 'Walk through the royal compound in ${_stops.length} '
                      'stops — from anywhere.',
              style: const TextStyle(fontSize: 16, height: 1.5,
                  color: AppColors.ink700)),
          const SizedBox(height: 20),
          StatusTag(am ? 'ፕሪሚየም' : 'Premium',
              icon: Icons.workspace_premium_outlined),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => pushScreen(context, const PremiumScreen()),
            icon: const Icon(Icons.workspace_premium),
            label: Text(am ? 'ፕሪሚየም ይመልከቱ' : 'See Premium'),
          ),
        ],
      ),
    );
  }
}

// ── The tour ────────────────────────────────────────────────────
class _Tour extends ConsumerStatefulWidget {
  const _Tour();
  @override
  ConsumerState<_Tour> createState() => _TourState();
}

class _TourState extends ConsumerState<_Tour> {
  final _ctrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Best photo for a stop from the live sites + places tables.
  String _photoFor(_Stop stop, List<Map<String, dynamic>> rows,
      String fallback) {
    for (final k in stop.keywords) {
      for (final r in rows) {
        final name = ((r['name_en'] ?? r['name'] ?? '') as String)
            .toLowerCase();
        final photo = (r['photo'] ?? '') as String;
        if (photo.isNotEmpty && name.contains(k)) return photo;
      }
    }
    return fallback;
  }

  void _go(int i) => _ctrl.animateToPage(i,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final am = isAm(ref.watch(languageProvider));
    final rows = [
      ...ref.watch(sitesProvider).valueOrNull ?? const <Map<String, dynamic>>[],
      ...ref.watch(placesProvider).valueOrNull ??
          const <Map<String, dynamic>>[],
    ];
    final fasil = _photoFor(_stops.first, rows, '');
    final last = _page == _stops.length - 1;

    return Scaffold(
      backgroundColor: AppColors.night1,
      body: Stack(children: [
        PageView.builder(
          controller: _ctrl,
          itemCount: _stops.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) => _StopPage(
            stop: _stops[i],
            index: i,
            am: am,
            photo: _photoFor(_stops[i], rows, fasil),
          ),
        ),

        // Top: close + progress
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(children: [
              Row(children: [
                IconButton(
                  tooltip: am ? 'ዝጋ' : 'Close',
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      minimumSize: const Size(44, 44)),
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(am ? 'የፋሲል ግቢ ምናባዊ ጉብኝት'
                          : 'Fasil Ghebbi · virtual tour',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                StatusTag(am ? 'ፕሪሚየም' : 'Premium',
                    background: Colors.white,
                    foreground: AppColors.ink),
              ]),
              const SizedBox(height: 10),
              ExcludeSemantics(
                child: Row(
                  children: List.generate(_stops.length, (i) => Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(
                              right: i == _stops.length - 1 ? 0 : 4),
                          decoration: BoxDecoration(
                            color: i <= _page
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      )),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: PressScale(
                  onTap: () => pushScreen(
                    context,
                    Panorama360Screen(
                      asset: _panorama,
                      am: am,
                      title: am ? _stops[_page].titleAm : _stops[_page].titleEn,
                      initialHeading: _panoramaHeadings[
                          _page % _panoramaHeadings.length],
                    ),
                  ),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.brandGold,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(
                          color: Color(0x55000000), blurRadius: 12)],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.threesixty_rounded,
                          size: 20, color: AppColors.black),
                      const SizedBox(width: 6),
                      Text(am ? 'በ360° ይመልከቱ' : 'Look around in 360°',
                          style: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.black)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),

        // Bottom: prev / ask / next
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(children: [
                IconButton(
                  tooltip: am ? 'ቀዳሚ' : 'Previous stop',
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      minimumSize: const Size(52, 52)),
                  onPressed: _page == 0 ? null : () => _go(_page - 1),
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      minimumSize: const Size(48, 52),
                    ),
                    onPressed: () =>
                        pushScreen(context, const AskGondarScreen()),
                    icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                    label: Text(am ? 'AI ይጠይቁ' : 'Ask AI'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.ink),
                    onPressed: last
                        ? () => Navigator.maybePop(context)
                        : () => _go(_page + 1),
                    child: Text(last
                        ? (am ? 'ጨርስ' : 'Finish')
                        : (am ? 'ቀጣይ' : 'Next stop')),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _StopPage extends StatelessWidget {
  final _Stop stop;
  final int index;
  final bool am;
  final String photo;
  const _StopPage({
    required this.stop,
    required this.index,
    required this.am,
    required this.photo,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      // Photo with a slow pan-and-zoom so it feels like walking in.
      if (photo.isNotEmpty)
        TweenAnimationBuilder<double>(
          key: ValueKey('kb-$index'),
          tween: Tween(begin: 1.0, end: 1.18),
          duration: const Duration(seconds: 14),
          curve: Curves.easeOut,
          builder: (_, s, child) => Transform.scale(
            scale: s,
            alignment: index.isEven
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: child,
          ),
          child: ShimmerImage(url: photo, borderRadius: BorderRadius.zero),
        )
      else
        Container(
          decoration: AppDecor.night(radius: 0),
          alignment: const Alignment(0, -0.35),
          child: Icon(stop.icon, size: 120,
              color: Colors.white.withValues(alpha: 0.25)),
        ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x99141414), Color(0x00141414), Color(0xF2141414)],
            stops: [0, 0.3, 0.72],
          ),
        ),
      ),
      Positioned(
        left: 20,
        right: 20,
        bottom: 100,
        child: SafeArea(
          top: false,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: Icon(stop.icon, size: 20, color: AppColors.ink),
              ),
              const SizedBox(width: 10),
              Kicker(
                  am ? 'ቦታ ${index + 1} ከ${_stops.length}'
                      : 'Stop ${index + 1} of ${_stops.length}',
                  color: Colors.white),
            ]),
            const SizedBox(height: 12),
            Text(am ? stop.titleAm : stop.titleEn,
                style: const TextStyle(color: Colors.white, fontSize: 28,
                    height: 1.2, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(am ? stop.bodyAm : stop.bodyEn,
                style: const TextStyle(color: Color(0xFFE6E6E6),
                    fontSize: 16, height: 1.55)),
          ]),
        ),
      ),
    ]);
  }
}
