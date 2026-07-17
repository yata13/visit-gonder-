import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/data_providers.dart';
import '../../providers/language_provider.dart';
import 'post_card.dart';
import 'post_detail_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  GONDAR TODAY — full news feed, every post the admin published.
// ═══════════════════════════════════════════════════════════════
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final postsAsync = ref.watch(postsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceVariant),
                  ),
                  child: const Icon(Icons.arrow_back,
                      size: 18, color: AppColors.charcoal),
                ),
              ),
              const SizedBox(width: 14),
              Text(tr(lang, 'gondar_today'),
                  style: const TextStyle(fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal, letterSpacing: -0.4)),
            ]),
          ),
          const SizedBox(height: 14),

          Expanded(
            child: postsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold)),
              error: (e, _) => const Center(
                child: Text('Could not load the feed',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
              data: (posts) => posts.isEmpty
                  ? const Center(
                      child: Text('No posts yet',
                          style: TextStyle(color: AppColors.textMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                      physics: const BouncingScrollPhysics(),
                      itemCount: posts.length,
                      itemBuilder: (_, i) => TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(
                            milliseconds: (250 + i * 60).clamp(250, 600)),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, child) => Opacity(
                            opacity: v,
                            child: Transform.translate(
                                offset: Offset(0, 20 * (1 - v)),
                                child: child)),
                        child: PostCard(
                          post: posts[i],
                          lang: lang,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) =>
                                  PostDetailScreen(
                                      post: posts[i], lang: lang))),
                        ),
                      ),
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}
