import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_theme.dart';
import '../../widgets/shimmer_image.dart';
import '../../providers/language_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  POST DETAIL — full view of a Gondar news feed post.
// ═══════════════════════════════════════════════════════════════
class PostDetailScreen extends StatelessWidget {
  final Map<String, dynamic> post;
  final String lang;
  const PostDetailScreen({super.key, required this.post, required this.lang});

  @override
  Widget build(BuildContext context) {
    final title = postField(post, 'title', lang);
    final body = postField(post, 'body', lang);
    final photo = (post['photo'] ?? '') as String;
    final created = DateTime.tryParse(post['created_at'] ?? '');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: GestureDetector(
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
            ),
            const SizedBox(height: 16),

            if (photo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Hero(
                  tag: 'post-${post['id']}',
                  child: ShimmerImage(
                    url: photo,
                    height: 230,
                    width: double.infinity,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // Author row
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.charcoal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('VG',
                          style: TextStyle(color: AppColors.gold,
                              fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Visit Gondar',
                        style: TextStyle(fontWeight: FontWeight.w800,
                            fontSize: 14, color: AppColors.charcoal)),
                    if (created != null)
                      Text(timeago.format(created),
                          style: const TextStyle(fontSize: 11.5,
                              color: AppColors.textMuted)),
                  ]),
                ]),
                const SizedBox(height: 16),

                Text(title,
                    style: const TextStyle(fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal,
                        height: 1.25, letterSpacing: -0.5)),
                const SizedBox(height: 14),
                Text(body,
                    style: const TextStyle(fontSize: 15,
                        color: AppColors.textSecondary, height: 1.7)),
                const SizedBox(height: 40),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
