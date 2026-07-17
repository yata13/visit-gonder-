import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

/// Network image with a shimmer loading effect, rounded corners,
/// and an optional soft dark overlay for text legibility.
class ShimmerImage extends StatelessWidget {
  final String url;
  final double? width, height;
  final BorderRadius borderRadius;
  final bool darkOverlay;
  final BoxFit fit;

  const ShimmerImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.darkOverlay = false,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(fit: StackFit.passthrough, children: [
        if (url.isEmpty)
          _placeholder()
        else
          CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 300),
            fadeInCurve: Curves.easeOut,
            placeholder: (_, __) => Shimmer.fromColors(
              baseColor: AppColors.surfaceVariant,
              highlightColor: AppColors.surfaceContainer,
              child: Container(
                width: width, height: height, color: Colors.white),
            ),
            errorWidget: (_, __, ___) => _placeholder(),
          ),
        if (darkOverlay)
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x11000000), Color(0xAA1C1410)],
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _placeholder() => Container(
    width: width, height: height,
    color: AppColors.surfaceVariant,
    child: const Center(
      child: Icon(Icons.image_outlined,
          color: AppColors.textMuted, size: 32),
    ),
  );
}
