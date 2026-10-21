import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

// ═══════════════════════════════════════════════════════════════
//  Small pieces shared by the driver screens.
// ═══════════════════════════════════════════════════════════════

IconData vehicleIcon(String? type) =>
    type == 'taxi' ? Icons.local_taxi_rounded : Icons.electric_rickshaw_rounded;

String vehicleName(String? type) => type == 'taxi' ? 'Taxi' : 'Bajaj';

/// 1250 → "1,250 ETB".
String money(Object? amount) {
  final n = amount is num ? amount.round() : num.tryParse('$amount')?.round() ?? 0;
  final digits = n.abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return '$out ETB';
}

String km(num value) =>
    value < 1 ? '${(value * 1000).round()} m' : '${value.toStringAsFixed(1)} km';

DateTime? parseTime(Object? v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

String timeAgo(Object? v) {
  final t = parseTime(v);
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "Today", "Yesterday" or "Mon 20 Oct".
String dayLabel(DateTime t) {
  final now = DateTime.now();
  if (sameDay(t, now)) return 'Today';
  if (sameDay(t, now.subtract(const Duration(days: 1)))) return 'Yesterday';
  return '${_days[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}';
}

String clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

void showSnack(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? VG.danger : VG.ink,
    ));
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String yes,
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Back')),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: VG.danger, minimumSize: const Size(48, 44))
              : FilledButton.styleFrom(minimumSize: const Size(48, 44)),
          onPressed: () => Navigator.pop(c, true),
          child: Text(yes),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<void> signOut() async {
  try {
    await Supabase.instance.client.auth.signOut();
  } catch (_) {
    // offline: the local session is still cleared
  }
}

/// Fades and slides its child in once, [delay] after it appears.
class FadeIn extends StatelessWidget {
  final Widget child;
  final int delay;
  const FadeIn({super.key, required this.child, this.delay = 0});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 420 + delay),
        curve: Interval(delay / (420 + delay), 1, curve: Curves.easeOutCubic),
        builder: (_, t, c) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: c),
        ),
        child: child,
      );
}

/// Round brand badge with an icon (top of sign-in, waiting screens).
class BrandBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const BrandBadge({super.key, required this.icon, this.color = VG.brown, this.size = 92});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, Colors.black, 0.25)!],
          ),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
          ],
        ),
        child: Icon(icon, color: VG.gold, size: size * 0.48),
      );
}

/// A blinking dot that says "this is live".
class LiveDot extends StatefulWidget {
  final Color color;
  const LiveDot({super.key, this.color = VG.online});
  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.25, end: 1.0).animate(_c),
        child: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      );
}

/// Label + value line on the details cards.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const InfoRow({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(icon, size: 20, color: VG.muted),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: VG.muted, fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: VG.ink)),
          ),
        ]),
      );
}

/// Pickup (green dot) → drop-off (brown flag) with the place names.
class RouteLines extends StatelessWidget {
  final String? from, to;
  const RouteLines({super.key, this.from, this.to});

  @override
  Widget build(BuildContext context) {
    Widget line(Widget mark, String text, {bool bold = false}) => Row(children: [
          SizedBox(width: 22, child: Center(child: mark)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15.5,
                    color: VG.ink,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
          ),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      line(
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: VG.online,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3)],
          ),
        ),
        from ?? 'Pickup point',
        bold: true,
      ),
      Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Container(width: 2, height: 14, color: VG.line),
      ),
      line(const Icon(Icons.flag_rounded, size: 18, color: VG.brown), to ?? 'Destination'),
    ]);
  }
}

/// Small rounded chip: "1.2 km away", "3 min ago".
class Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const Pill({super.key, required this.icon, required this.text, this.color = VG.muted});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}
