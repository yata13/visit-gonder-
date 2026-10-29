import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/language_provider.dart';
import '../../providers/passport_provider.dart';
import '../../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  PASSPORT SCAN — point the camera at the QR code on a site's
//  Passport sign. The QR holds the site's check-in code; the server
//  checks it (passport_check_in) and the screen closes with the
//  result so the stamp dialog can show.
// ═══════════════════════════════════════════════════════════════
class PassportScanScreen extends ConsumerStatefulWidget {
  const PassportScanScreen({super.key});
  @override
  ConsumerState<PassportScanScreen> createState() => _PassportScanScreenState();
}

class _PassportScanScreenState extends ConsumerState<PassportScanScreen> {
  final _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    // Some Android devices auto-pick an odd native camera resolution that
    // breaks the preview's cover-fit scaling (it renders as a tiny strip
    // instead of filling the screen). A fixed, widely-supported resolution
    // avoids that.
    cameraResolution: const Size(1280, 720),
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final code = capture.barcodes
        .map((b) => b.rawValue?.trim() ?? '')
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (code.isEmpty) return;
    final am = isAm(ref.read(languageProvider));
    setState(() {
      _busy = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();
    try {
      final res = await passportCheckIn(code);
      if (mounted) Navigator.pop(context, res);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.code == 'P0002'
            ? (am ? 'ይህ የፓስፖርት QR ኮድ አይደለም።'
                : 'This is not a Passport QR code. Try the sign at the site.')
            : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = am ? 'ኢንተርኔት የለም። እንደገና ይሞክሩ።'
            : 'No connection. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final am = isAm(ref.watch(languageProvider));
    final size = MediaQuery.sizeOf(context);
    final box = size.width * 0.7;
    final window = Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.42),
        width: box,
        height: box);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: MobileScanner(
            controller: _camera,
            scanWindow: window,
            onDetect: _onDetect,
            errorBuilder: (_, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? (am ? 'ካሜራውን ለመጠቀም ፈቃድ ይስጡ (ቅንብሮች › መተግበሪያዎች)።'
                          : 'Allow camera access to scan (Settings › Apps › Visit Gondar).')
                      : (am ? 'ካሜራው አልተከፈተም።' : 'The camera could not start.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
        // Dim everything except the scan window.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _WindowPainter(window)),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              IconButton(
                tooltip: am ? 'ዝጋ' : 'Close',
                style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    minimumSize: const Size(44, 44)),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                tooltip: am ? 'መብራት' : 'Torch',
                style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    minimumSize: const Size(44, 44)),
                onPressed: () => _camera.toggleTorch(),
                icon: const Icon(Icons.flashlight_on_rounded,
                    color: Colors.white),
              ),
            ]),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          top: window.bottom + 24,
          child: Column(children: [
            Text(
                _busy
                    ? (am ? 'በመፈተሽ ላይ…' : 'Checking in…')
                    : (am ? 'በቦታው ያለውን የፓስፖርት QR ኮድ ይቃኙ'
                        : 'Point at the QR code on the Passport sign'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.w800)),
            if (_busy) ...[
              const SizedBox(height: 14),
              const CircularProgressIndicator(color: AppColors.brandGold),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.clayTint,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.clayInk,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _WindowPainter extends CustomPainter {
  final Rect window;
  _WindowPainter(this.window);

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(window, const Radius.circular(24));
    canvas.drawPath(
      Path.combine(PathOperation.difference,
          Path()..addRect(Offset.zero & size), Path()..addRRect(hole)),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawRRect(
      hole,
      Paint()
        ..color = AppColors.brandGold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(_WindowPainter old) => old.window != window;
}
