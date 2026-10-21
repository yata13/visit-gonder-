import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/data_providers.dart';
import '../../providers/language_provider.dart';
import '../../services/location_service.dart';
import '../../services/ride_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/motion.dart';
import '../../widgets/ui.dart';
import '../auth/login_screen.dart';
import '../stay/stay_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  RIDE — request a bajaj or taxi from a Visit Gondar partner
//  driver. Pick where to go, see the price, request; then follow
//  the driver live on the map until you arrive, and rate them.
//  Pay the driver in cash. Drivers use the Visit Gondar Driver app.
// ═══════════════════════════════════════════════════════════════
class RideScreen extends ConsumerStatefulWidget {
  /// Optional destination chosen elsewhere (e.g. a place on the map).
  final RidePlace? destination;
  const RideScreen({super.key, this.destination});

  @override
  ConsumerState<RideScreen> createState() => _RideScreenState();
}

enum _Picking { none, pickup, dropoff }

class _RideScreenState extends ConsumerState<RideScreen> {
  static const _piassa = LatLng(12.6075, 37.4592);
  static const _dismissedKey = 'ride_dismissed';

  final _map = MapController();
  bool _mapReady = false;

  RidePlace? _pickup;
  late RidePlace? _dropoff = widget.destination;
  VehicleType _type = VehicleType.bajaj;
  final Map<VehicleType, RideQuote> _quotes = {};
  bool _quoting = false;
  String? _quoteError;
  String? _locError;
  bool _locating = true;

  _Picking _picking = _Picking.none;
  bool _busy = false;
  String? _error;

  final _phone = TextEditingController();
  String _name = '';
  Set<String> _dismissed = {};
  String? _fittedFor; // ride id + status the map was last framed for
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _locate();
    _loadContact();
    // Re-render every 20 s so "finding a driver…" times stay fresh.
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _loadContact() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = Supabase.instance.client.auth.currentUser;
      final meta = user?.userMetadata;
      setState(() {
        _phone.text = prefs.getString(AppConstants.prefMyContact) ?? '';
        _name = (meta?['full_name'] ?? meta?['name'] ??
                user?.email?.split('@').first ?? '') as String;
        _dismissed = (prefs.getStringList(_dismissedKey) ?? const []).toSet();
      });
    } catch (_) {}
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locError = null;
    });
    LocationResult res;
    try {
      res = await LocationService.current();
    } catch (_) {
      res = const LocationResult(
          error: 'Could not get your location. Set your pickup on the map.');
    }
    if (!mounted) return;
    final am = isAm(ref.read(languageProvider));
    setState(() {
      _locating = false;
      if (res.ok) {
        _pickup = RidePlace(am ? 'ያሉበት ቦታ' : 'My location',
            LatLng(res.position!.latitude, res.position!.longitude));
      } else {
        _locError = res.error;
      }
    });
    _frame();
    _refreshQuotes();
  }

  Future<void> _refreshQuotes() async {
    final p = _pickup, d = _dropoff;
    if (p == null || d == null) return;
    setState(() {
      _quoting = true;
      _quoteError = null;
    });
    try {
      final results = await Future.wait([
        RideService.quote(VehicleType.bajaj, p.point, d.point),
        RideService.quote(VehicleType.taxi, p.point, d.point),
      ]);
      if (!mounted) return;
      setState(() {
        _quotes[VehicleType.bajaj] = results[0];
        _quotes[VehicleType.taxi] = results[1];
      });
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _quoteError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _quoteError = 'Could not get a price. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  /// Frames the map around the points that matter right now.
  void _frame([List<LatLng>? points]) {
    if (!_mapReady) return;
    final pts = points ??
        [if (_pickup != null) _pickup!.point, if (_dropoff != null) _dropoff!.point];
    if (pts.isEmpty) {
      _map.move(_piassa, 14.5);
    } else if (pts.length == 1) {
      _map.move(pts.first, 15.5);
    } else {
      _map.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pts),
        padding: const EdgeInsets.fromLTRB(60, 140, 60, 380),
        maxZoom: 16.5,
      ));
    }
  }

  Future<void> _dismiss(String rideId) async {
    setState(() => _dismissed.add(rideId));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_dismissedKey, _dismissed.toList());
    } catch (_) {}
  }

  Future<void> _request(bool am) async {
    final p = _pickup, d = _dropoff;
    if (p == null || d == null) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      pushScreen(context, const LoginScreen());
      return;
    }
    final phone = _phone.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = am
          ? 'ሾፌሩ እንዲደውልልዎ ስልክ ቁጥርዎን ያስገቡ።'
          : 'Add your phone number so the driver can call you.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.prefMyContact, phone);
      await RideService.request(
          type: _type, pickup: p, dropoff: d, name: _name, phone: phone);
      ref.invalidate(myLatestRideProvider);
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = am ? 'ኢንተርኔት የለም። እንደገና ይሞክሩ።'
          : 'No connection. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(Map<String, dynamic> ride, bool am) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(am ? 'ጉዞውን ይሰርዙ?' : 'Cancel this ride?'),
        content: Text(ride['status'] == 'requested'
            ? (am ? 'ሾፌር መፈለግ ይቆማል።' : 'We will stop looking for a driver.')
            : (am ? 'ሾፌሩ ይነገረዋል።' : 'Your driver will be told.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false),
              child: Text(am ? 'አይ' : 'Keep ride')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.sos),
            onPressed: () => Navigator.pop(c, true),
            child: Text(am ? 'ሰርዝ' : 'Cancel ride'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await RideService.cancel('${ride['id']}');
      ref.invalidate(myLatestRideProvider);
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _tryAgain(Map<String, dynamic> ride, bool am) async {
    setState(() {
      _pickup = RidePlace((ride['pickup_label'] ?? 'Pickup') as String,
          LatLng((ride['pickup_lat'] as num).toDouble(), (ride['pickup_lng'] as num).toDouble()));
      _dropoff = RidePlace((ride['dropoff_label'] ?? 'Destination') as String,
          LatLng((ride['dropoff_lat'] as num).toDouble(), (ride['dropoff_lng'] as num).toDouble()));
      _type = ride['vehicle_type'] == 'taxi' ? VehicleType.taxi : VehicleType.bajaj;
    });
    try {
      if (ride['status'] == 'requested') await RideService.cancel('${ride['id']}');
    } catch (_) {}
    await _dismiss('${ride['id']}');
    if (mounted) await _request(am);
  }

  /// Should this ride still fill the panel?
  bool _isShown(Map<String, dynamic>? ride) {
    if (ride == null) return false;
    final id = '${ride['id']}', status = ride['status'] as String? ?? '';
    if (liveRideStatuses.contains(status)) return true;
    if (_dismissed.contains(id)) return false;
    final at = DateTime.tryParse('${ride['completed_at'] ?? ride['cancelled_at'] ?? ride['created_at']}');
    final recent = at != null && DateTime.now().toUtc().difference(at.toUtc()) < const Duration(hours: 3);
    if (status == 'completed') return recent && ride['rider_rating'] == null;
    return recent && (status == 'expired' || ride['cancelled_by'] == 'admin');
  }

  void _pickDestination(bool am) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => _DestinationSheet(
        am: am,
        onPick: (p) {
          Navigator.pop(sheet);
          setState(() => _dropoff = p);
          _frame();
          _refreshQuotes();
        },
        onMap: () {
          Navigator.pop(sheet);
          setState(() => _picking = _Picking.dropoff);
        },
      ),
    );
  }

  void _confirmPin(bool am) {
    final center = _map.camera.center;
    setState(() {
      if (_picking == _Picking.pickup) {
        _pickup = RidePlace(am ? 'በካርታ ላይ የተመረጠ' : 'Pinned pickup', center);
      } else {
        _dropoff = RidePlace(am ? 'በካርታ ላይ የተመረጠ' : 'Pinned on the map', center);
      }
      _picking = _Picking.none;
    });
    _frame();
    _refreshQuotes();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final am = isAm(lang);
    final ride = ref.watch(myLatestRideProvider).valueOrNull;
    // Keep the destination list loaded while this screen is open.
    ref.watch(sitesProvider);
    ref.watch(hotelsProvider);
    ref.watch(placesProvider);
    final shown = _isShown(ride) ? ride : null;

    LatLng? driver;
    if (shown != null && shown['driver_lat'] is num && shown['driver_lng'] is num) {
      driver = LatLng((shown['driver_lat'] as num).toDouble(),
          (shown['driver_lng'] as num).toDouble());
    }
    LatLng? ridePickup, rideDropoff;
    if (shown != null) {
      ridePickup = LatLng((shown['pickup_lat'] as num).toDouble(),
          (shown['pickup_lng'] as num).toDouble());
      rideDropoff = LatLng((shown['dropoff_lat'] as num).toDouble(),
          (shown['dropoff_lng'] as num).toDouble());
      // Re-frame when the ride changes stage.
      final key = '${shown['id']}:${shown['status']}';
      if (_fittedFor != key) {
        _fittedFor = key;
        WidgetsBinding.instance.addPostFrameCallback((_) => _frame([
              if (shown['status'] == 'in_progress') rideDropoff! else ridePickup!,
              if (driver != null) driver else rideDropoff!,
            ]));
      }
    }
    final pickupPt = ridePickup ?? _pickup?.point;
    final dropoffPt = rideDropoff ?? _dropoff?.point;
    final vehicleIcon = (shown?['vehicle_type'] ?? _type.name) == 'taxi'
        ? Icons.local_taxi_rounded
        : Icons.electric_rickshaw_rounded;

    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _piassa,
              initialZoom: 14.5,
              minZoom: 11,
              maxZoom: 18,
              onMapReady: () {
                _mapReady = true;
                _frame();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: AppConstants.mapTiles,
                userAgentPackageName: 'com.visitgondar.app',
                maxNativeZoom: 19,
              ),
              if (pickupPt != null && dropoffPt != null)
                PolylineLayer(polylines: [
                  Polyline(
                    points: [pickupPt, dropoffPt],
                    color: AppColors.brandBrown,
                    strokeWidth: 3,
                    pattern: StrokePattern.dashed(segments: const [10, 8]),
                  ),
                ]),
              MarkerLayer(markers: [
                if (pickupPt != null && _picking != _Picking.pickup)
                  Marker(
                    point: pickupPt,
                    width: 26,
                    height: 26,
                    child: const _Dot(color: AppColors.locationBlue),
                  ),
                if (dropoffPt != null && _picking != _Picking.dropoff)
                  Marker(
                    point: dropoffPt,
                    width: 40,
                    height: 40,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.flag_rounded,
                        color: AppColors.brandBrown, size: 36),
                  ),
                if (driver != null)
                  Marker(
                    point: driver,
                    width: 44,
                    height: 44,
                    child: _DriverPin(icon: vehicleIcon),
                  ),
              ]),
              const SimpleAttributionWidget(
                alignment: Alignment.topRight,
                source: Text('OpenStreetMap contributors'),
              ),
            ],
          ),
        ),

        // Pin in the middle of the map while choosing a point.
        if (_picking != _Picking.none)
          Positioned.fill(
           child: IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Icon(
                    _picking == _Picking.pickup
                        ? Icons.my_location_rounded
                        : Icons.location_on_rounded,
                    size: 44,
                    color: AppColors.brandBrown),
              ),
            ),
           ),
          ),

        // Top bar — pinned, so the map (not this bar) sizes the screen.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              GlassCircleButton(
                icon: Icons.arrow_back_rounded,
                semanticLabel: am ? 'ተመለስ' : 'Back',
                onTap: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.centerLeft,
                  decoration: AppDecor.glass(radius: 22),
                  child: Text(am ? 'ባጃጅ እና ታክሲ' : 'Ride · bajaj & taxi',
                      style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              GlassCircleButton(
                icon: Icons.phone_in_talk_rounded,
                semanticLabel: am ? 'ሾፌር ይደውሉ' : 'Call a driver directly',
                onTap: () => pushScreen(context, const StayScreen(initialTab: 1)),
              ),
            ]),
          ),
          ),
        ),

        // Bottom panel
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _picking != _Picking.none
              ? _PinPanel(
                  am: am,
                  pickup: _picking == _Picking.pickup,
                  onConfirm: () => _confirmPin(am),
                  onCancel: () => setState(() => _picking = _Picking.none),
                )
              : AnimatedSwitcher(
                  duration: Motion.medium,
                  switchInCurve: Motion.curve,
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.15), end: Offset.zero)
                          .animate(a),
                      child: c,
                    ),
                  ),
                  child: shown != null
                      ? _LivePanel(
                          key: ValueKey('live-${shown['id']}-${shown['status']}'),
                          ride: shown,
                          am: am,
                          driver: driver,
                          onCancel: () => _cancel(shown, am),
                          onTryAgain: () => _tryAgain(shown, am),
                          onDone: () {
                            _dismiss('${shown['id']}');
                            // A finished trip starts the next one fresh.
                            if (shown['status'] == 'completed') {
                              setState(() {
                                _dropoff = null;
                                _quotes.clear();
                              });
                            }
                          },
                        )
                      : _requestPanel(am, lang),
                ),
        ),
      ]),
    );
  }

  Widget _requestPanel(bool am, String lang) {
    final ready = _pickup != null && _dropoff != null;
    final quote = _quotes[_type];
    return _Sheet(
      key: const ValueKey('request'),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        // From / to
        _PlaceRow(
          icon: Icons.my_location_rounded,
          color: AppColors.locationBlue,
          label: am ? 'ከ' : 'From',
          value: _locating
              ? (am ? 'ቦታዎን በመፈለግ ላይ…' : 'Finding your location…')
              : _pickup?.label ?? (am ? 'መነሻ ይምረጡ' : 'Choose pickup on the map'),
          onTap: () => setState(() => _picking = _Picking.pickup),
          trailing: IconButton(
            tooltip: am ? 'ያሉበትን ቦታ ተጠቀም' : 'Use my location',
            onPressed: _locate,
            icon: const Icon(Icons.gps_fixed_rounded, size: 20),
          ),
        ),
        const Divider(height: 1, indent: 44),
        _PlaceRow(
          icon: Icons.flag_rounded,
          color: AppColors.brandBrown,
          label: am ? 'ወደ' : 'To',
          value: _dropoff?.label ?? (am ? 'ወዴት ይሄዳሉ?' : 'Where to?'),
          emphasize: _dropoff == null,
          onTap: () => _pickDestination(am),
        ),
        if (_locError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_locError!,
                style: const TextStyle(fontSize: 12, color: AppColors.clayInk)),
          ),
        const SizedBox(height: 12),

        // Vehicle + price
        Row(children: [
          for (final t in VehicleType.values) ...[
            if (t == VehicleType.taxi) const SizedBox(width: 10),
            Expanded(
              child: _VehicleCard(
                type: t,
                am: am,
                selected: _type == t,
                quote: _quotes[t],
                loading: _quoting,
                onTap: () => setState(() => _type = t),
              ),
            ),
          ],
        ]),
        if (_quoteError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_quoteError!,
                style: const TextStyle(fontSize: 13, color: AppColors.clayInk,
                    fontWeight: FontWeight.w600)),
          ),
        const SizedBox(height: 10),

        // Phone for the driver
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.phone_rounded, size: 20),
            labelText: am ? 'ስልክዎ (ለሾፌሩ)' : 'Your phone (for the driver)',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style: const TextStyle(color: AppColors.clayInk,
                  fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: !ready || _busy || quote == null ? null : () => _request(am),
          icon: _busy
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Icon(_type == VehicleType.taxi
                  ? Icons.local_taxi_rounded
                  : Icons.electric_rickshaw_rounded),
          label: Text(!ready
              ? (am ? 'መድረሻ ይምረጡ' : 'Choose where to go')
              : quote == null
                  ? (am ? 'ዋጋ በማስላት ላይ…' : 'Getting the price…')
                  : am
                      ? '${_type == VehicleType.taxi ? 'ታክሲ' : 'ባጃጅ'} ይጥሩ · ${quote.fare.round()} ብር'
                      : 'Request ${_type.name} · ${quote.fare.round()} ETB'),
        ),
        const SizedBox(height: 6),
        Text(am ? 'ለሾፌሩ በጥሬ ገንዘብ ይክፈሉ። የተረጋገጡ የVisit Gondar አጋሮች።'
                : 'Pay the driver in cash · verified Visit Gondar partners',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ]),
    );
  }
}

// ── Live ride panel ───────────────────────────────────────────
class _LivePanel extends StatefulWidget {
  final Map<String, dynamic> ride;
  final bool am;
  final LatLng? driver;
  final VoidCallback onCancel, onTryAgain, onDone;
  const _LivePanel({
    super.key,
    required this.ride,
    required this.am,
    required this.driver,
    required this.onCancel,
    required this.onTryAgain,
    required this.onDone,
  });

  @override
  State<_LivePanel> createState() => _LivePanelState();
}

class _LivePanelState extends State<_LivePanel> {
  int _stars = 0;
  bool _rating = false;

  Map<String, dynamic> get r => widget.ride;

  Future<void> _rate() async {
    if (_stars == 0) return;
    setState(() => _rating = true);
    try {
      await RideService.rate('${r['id']}', _stars);
      widget.onDone();
    } catch (_) {
      if (mounted) setState(() => _rating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final am = widget.am;
    final status = r['status'] as String? ?? '';
    final fare = (r['fare_estimate'] as num?)?.round() ?? 0;
    final vehicle = r['vehicle_type'] == 'taxi'
        ? (am ? 'ታክሲ' : 'taxi')
        : (am ? 'ባጃጅ' : 'bajaj');
    final created = DateTime.tryParse('${r['created_at']}')?.toLocal();
    final waitedMin = created == null ? 0 : DateTime.now().difference(created).inMinutes;
    final pickup = LatLng((r['pickup_lat'] as num).toDouble(), (r['pickup_lng'] as num).toDouble());

    String title, subtitle;
    switch (status) {
      case 'requested':
        final stale = waitedMin >= 15;
        title = stale
            ? (am ? 'ገና ሾፌር አልተገኘም' : 'No driver has accepted yet')
            : (am ? 'ሾፌር በመፈለግ ላይ…' : 'Finding your $vehicle driver…');
        subtitle = stale
            ? (am ? 'እንደገና ይሞክሩ ወይም በቀጥታ ሾፌር ይደውሉ።'
                : 'Try again, or call a driver directly.')
            : (am ? 'በአቅራቢያ ያሉ ሾፌሮች ጥያቄዎን እያዩ ነው።'
                : 'Nearby drivers are seeing your request.');
      case 'accepted':
        final km = widget.driver == null ? null : kmBetween(widget.driver!, pickup);
        title = am ? 'ሾፌርዎ እየመጣ ነው' : 'Your driver is on the way';
        subtitle = km == null
            ? (am ? 'ተቀብሏል' : 'Accepted your ride')
            : am
                ? '${km.toStringAsFixed(1)} ኪሜ ቀርቷል · ~${etaMinutes(km)} ደቂቃ'
                : '${km.toStringAsFixed(1)} km away · about ${etaMinutes(km)} min';
      case 'arrived':
        title = am ? 'ሾፌርዎ ደርሷል!' : 'Your driver is here!';
        subtitle = am ? 'ሰሌዳ ${r['vehicle_plate'] ?? ''} ይፈልጉ።'
            : 'Look for plate ${r['vehicle_plate'] ?? ''}.';
      case 'in_progress':
        title = am ? 'በጉዞ ላይ' : 'On your way';
        subtitle = am ? 'ወደ ${r['dropoff_label'] ?? ''}'
            : 'To ${r['dropoff_label'] ?? 'your destination'}';
      case 'completed':
        title = am ? 'ደርሰዋል 🎉' : 'You have arrived 🎉';
        subtitle = am ? 'ለሾፌሩ $fare ብር በጥሬ ገንዘብ ይክፈሉ።'
            : 'Please pay the driver $fare ETB in cash.';
      case 'expired':
        title = am ? 'ሾፌር አልተገኘም' : 'No driver was found';
        subtitle = am ? 'እንደገና ይሞክሩ።' : 'Please try again in a moment.';
      default:
        title = am ? 'ጉዞው ተሰርዟል' : 'This ride was cancelled';
        subtitle = (r['cancel_reason'] ?? (am ? 'በVisit Gondar ቡድን' : 'by the Visit Gondar team'))
            as String;
    }

    final hasDriver = r['driver_name'] != null &&
        {'accepted', 'arrived', 'in_progress', 'completed'}.contains(status);

    return _Sheet(
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: Reveal.stagger(stepMs: 45, [
        Row(children: [
          if (status == 'requested' && waitedMin < 15)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.6,
                      color: AppColors.brandGold)),
            ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800,
                      color: AppColors.black)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            ]),
          ),
        ]),
        if (status == 'requested' && waitedMin < 15) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(
              minHeight: 4, color: AppColors.brandGold, backgroundColor: AppColors.stone),
        ],
        if (hasDriver) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.goldTint,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.brandBrown,
                child: Text(
                    ('${r['driver_name']}'.trim().isEmpty ? '?' : '${r['driver_name']}'.trim()[0])
                        .toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r['driver_name']}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(
                      [r['vehicle_plate'], r['vehicle_desc']]
                          .where((v) => v != null && '$v'.isNotEmpty)
                          .join(' · '),
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ]),
              ),
              if (status != 'completed' && r['driver_phone'] != null)
                IconButton.filled(
                  tooltip: am ? 'ይደውሉ' : 'Call driver',
                  style: IconButton.styleFrom(backgroundColor: AppColors.safe),
                  onPressed: () => launchUrl(Uri.parse('tel:${r['driver_phone']}')),
                  icon: const Icon(Icons.call_rounded, color: Colors.white),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.payments_outlined, size: 18, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
                am ? 'ዋጋ: $fare ብር (በጥሬ ገንዘብ)' : 'Fare: $fare ETB · cash',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          Text('${(r['distance_km'] as num?)?.toStringAsFixed(1) ?? '-'} km',
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        ]),
        const SizedBox(height: 14),
        if (status == 'completed') ...[
          Text(am ? 'ሾፌሩን ይገምግሙ' : 'Rate your driver',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i',
                  onPressed: () => setState(() => _stars = i),
                  icon: Icon(i <= _stars ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 36, color: AppColors.brandGold),
                ),
            ],
          ),
          FilledButton(
            onPressed: _stars == 0 || _rating ? null : _rate,
            child: Text(am ? 'ግምገማ ላክ' : 'Send rating'),
          ),
          TextButton(onPressed: widget.onDone, child: Text(am ? 'ዝለል' : 'Skip')),
        ] else if (status == 'expired' || (status == 'requested' && waitedMin >= 15)) ...[
          FilledButton(onPressed: widget.onTryAgain,
              child: Text(am ? 'እንደገና ይሞክሩ' : 'Try again')),
          TextButton(
            onPressed: status == 'requested' ? widget.onCancel : widget.onDone,
            child: Text(am ? 'ዝጋ' : 'Close'),
          ),
        ] else if (status == 'cancelled') ...[
          FilledButton(onPressed: widget.onDone, child: Text(am ? 'እሺ' : 'OK')),
        ] else if (status != 'in_progress')
          OutlinedButton(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.sos,
                side: const BorderSide(color: AppColors.sos, width: 1.5),
                minimumSize: const Size(48, 48)),
            onPressed: widget.onCancel,
            child: Text(am ? 'ጉዞውን ሰርዝ' : 'Cancel ride'),
          ),
      ])),
    );
  }
}

// ── Small pieces ──────────────────────────────────────────────
class _Sheet extends StatelessWidget {
  final Widget child;
  const _Sheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
          boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 24,
              offset: Offset(0, -6))],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 12 + MediaQuery.viewInsetsOf(context).bottom),
            child: child,
          ),
        ),
      );
}

class _PlaceRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  final bool emphasize;
  final VoidCallback onTap;
  final Widget? trailing;
  const _PlaceRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
    this.emphasize = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            SizedBox(width: 36, child: Icon(icon, color: color, size: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted,
                        fontWeight: FontWeight.w700)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: emphasize ? 17 : 15,
                        fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                        color: AppColors.black)),
              ]),
            ),
            ?trailing,
          ]),
        ),
      );
}

class _VehicleCard extends StatelessWidget {
  final VehicleType type;
  final bool am, selected, loading;
  final RideQuote? quote;
  final VoidCallback onTap;
  const _VehicleCard({
    required this.type,
    required this.am,
    required this.selected,
    required this.loading,
    required this.quote,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final taxi = type == VehicleType.taxi;
    return Semantics(
      button: true,
      selected: selected,
      child: PressScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.curve,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppColors.goldTint : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? AppColors.brandBrown : AppColors.line,
                width: selected ? 2 : 1),
          ),
          child: Row(children: [
            Icon(taxi ? Icons.local_taxi_rounded : Icons.electric_rickshaw_rounded,
                size: 30, color: AppColors.brandBrown),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(taxi ? (am ? 'ታክሲ' : 'Taxi') : (am ? 'ባጃጅ' : 'Bajaj'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                Text(
                    quote != null
                        ? '${quote!.fare.round()} ${am ? 'ብር' : 'ETB'}'
                        : loading
                            ? '…'
                            : (taxi ? (am ? '4 ሰው' : 'Up to 4') : (am ? '3 ሰው' : 'Up to 3')),
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PinPanel extends StatelessWidget {
  final bool am, pickup;
  final VoidCallback onConfirm, onCancel;
  const _PinPanel({required this.am, required this.pickup,
      required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) => _Sheet(
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(pickup
                  ? (am ? 'መነሻውን ለማስተካከል ካርታውን ያንቀሳቅሱ' : 'Move the map to set your pickup')
                  : (am ? 'መድረሻውን ለማስተካከል ካርታውን ያንቀሳቅሱ' : 'Move the map to set where to go'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onConfirm,
              child: Text(pickup ? (am ? 'እዚህ ውሰደኝ' : 'Pick me up here')
                  : (am ? 'ወደዚህ' : 'Go here'))),
          TextButton(onPressed: onCancel, child: Text(am ? 'ተመለስ' : 'Back')),
        ]),
      );
}

class _DestinationSheet extends ConsumerStatefulWidget {
  final bool am;
  final ValueChanged<RidePlace> onPick;
  final VoidCallback onMap;
  const _DestinationSheet(
      {required this.am, required this.onPick, required this.onMap});

  @override
  ConsumerState<_DestinationSheet> createState() => _DestinationSheetState();
}

class _DestinationSheetState extends ConsumerState<_DestinationSheet> {
  String _q = '';

  /// Sites, hotels and map places that have a pin, A–Z, no repeats.
  List<RidePlace> _places(String lang) {
    final rows = <Map<String, dynamic>>[
      ...ref.watch(sitesProvider).valueOrNull ?? const [],
      ...ref.watch(hotelsProvider).valueOrNull ?? const [],
      ...ref.watch(placesProvider).valueOrNull ?? const [],
    ];
    final seen = <String>{};
    final out = <RidePlace>[];
    for (final r in rows) {
      final lat = r['lat'], lng = r['lng'];
      if (lat is! num || lng is! num) continue;
      final name = localName(r, lang);
      if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
      out.add(RidePlace(name, LatLng(lat.toDouble(), lng.toDouble())));
    }
    out.sort((a, b) => a.label.compareTo(b.label));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final am = widget.am;
    final list = _places(ref.watch(languageProvider))
        .where((p) => _q.isEmpty || p.label.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: am ? 'ቦታ፣ ሆቴል ይፈልጉ' : 'Search places, hotels, sites',
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.pin_drop_outlined, color: AppColors.brandBrown),
            title: Text(am ? 'በካርታ ላይ ይምረጡ' : 'Choose on the map',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            onTap: widget.onMap,
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(list[i].label),
                onTap: () => widget.onPick(list[i]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10)],
        ),
      );
}

class _DriverPin extends StatelessWidget {
  final IconData icon;
  const _DriverPin({required this.icon});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.brandBrown,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10)],
        ),
        child: Icon(icon, color: AppColors.brandGold, size: 24),
      );
}
