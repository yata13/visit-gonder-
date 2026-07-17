import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_theme.dart';
import '../../widgets/shimmer_image.dart';
import '../../providers/language_provider.dart';

/// Facebook-style feed card for a Gondar news post.
/// Used on the home feed and the full "Gondar Today" list.
class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final String lang;
  final VoidCallback onTap;
  const PostCard(
      {super.key,
      required this.post,
      required this.lang,
      required this.onTap});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 150));
  late final Animation<double> _scale = Tween(begin: 1.0, end: 0.97)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final lang = widget.lang;
    final title = postField(post, 'title', lang);
    final body = postField(post, 'body', lang);
    final photo = (post['photo'] ?? '') as String;
    final created = DateTime.tryParse(post['created_at'] ?? '');

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
                color: AppColors.charcoal.withAlpha(12),
                blurRadius: 14, offset: const Offset(0, 5))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Author row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.charcoal,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Center(
                    child: Text('VG',
                        style: TextStyle(color: AppColors.gold,
                            fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Visit Gondar',
                      style: TextStyle(fontWeight: FontWeight.w800,
                          fontSize: 13.5, color: AppColors.charcoal)),
                  if (created != null)
                    Text(timeago.format(created),
                        style: const TextStyle(fontSize: 11,
                            color: AppColors.textMuted)),
                ]),
                const Spacer(),
                const Icon(Icons.verified,
                    size: 16, color: AppColors.gold),
              ]),
            ),

            if (photo.isNotEmpty)
              Hero(
                tag: 'post-${post['id']}',
                child: ShimmerImage(
                  url: photo,
                  height: 180,
                  width: double.infinity,
                  borderRadius: BorderRadius.zero,
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal, height: 1.3)),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(body,
                      maxLines: 3, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5,
                          color: AppColors.textSecondary, height: 1.55)),
                ],
                const SizedBox(height: 10),
                Row(children: [
                  Text(tr(lang, 'read_more'),
                      style: const TextStyle(color: AppColors.rust,
                          fontWeight: FontWeight.w700, fontSize: 12.5)),
                  const SizedBox(width: 3),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 13, color: AppColors.rust),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
