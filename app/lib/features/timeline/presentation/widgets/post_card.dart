import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/linkified_text.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../domain/post.dart';
import 'post_image_gallery.dart';
import 'post_tag_chip.dart';
import 'questionnaire_card.dart';

/// Kartu postingan di linimasa (mengikuti desain Home).
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onOpen,
    this.onVote,
    this.onSave,
    this.onShare,
    this.onMenu,
    this.onImageTap,
    this.onAuthorTap,
    this.expanded = false,
  });

  final Post post;

  /// Buka detail (ketuk kartu, judul, atau tombol komentar).
  final VoidCallback? onOpen;

  /// Arah suara: 1 atau -1.
  final ValueChanged<int>? onVote;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final VoidCallback? onMenu;
  final ValueChanged<int>? onImageTap;

  /// Ketuk avatar/nama penulis (buka profilnya). Kosong untuk anonim.
  final VoidCallback? onAuthorTap;

  /// Tampilan detail: isi tidak dipotong dan tanpa "Selengkapnya".
  final bool expanded;

  static bool _isLong(String body) =>
      body.length > 220 || '\n'.allMatches(body).length >= 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final parts = post.parts;
    final now = DateTime.now();
    final timeLeft = post.expiresAt.difference(now);
    final endingSoon = !post.isClosed && timeLeft < const Duration(hours: 48);

    return GlassContainer(
      radius: 28,
      blur: 16,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kepala: avatar, nama, prodi · waktu, menu.
          Row(
            children: [
              GestureDetector(
                onTap: onAuthorTap,
                child: UserAvatar(
                  initials: post.authorInitials,
                  imagePath: post.authorAvatar,
                  size: 40,
                  glass: false,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: onAuthorTap,
                            child: Text(
                              post.authorLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        if (post.isOfficial) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppColors.brandBlue,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      [
                        if (post.authorProdi != null) post.authorProdi!,
                        Fmt.ago(post.createdAt, now: now),
                        if (post.isEdited) 'Diedit',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onMenu,
                tooltip: 'Menu postingan',
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (post.isOfficial)
                      const PostTagChip(
                        label: 'Pengumuman resmi',
                        icon: Icons.push_pin_rounded,
                      ),
                    if (post.isClosed)
                      const PostTagChip(
                        label: 'Selesai',
                        icon: Icons.check_circle_outline_rounded,
                      ),
                    for (final t in post.tags) PostTagChip(label: t.name),
                    if (endingSoon)
                      PostTagChip(
                        label:
                            'Hilang ${Fmt.remaining(timeLeft.isNegative ? Duration.zero : timeLeft)}',
                        icon: Icons.hourglass_bottom_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (parts.title != null) ...[
                        Text(
                          parts.title!,
                          maxLines: expanded ? null : 3,
                          overflow: expanded ? null : TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      LinkifiedText(
                        parts.body,
                        maxLines: expanded ? null : 6,
                        overflow: expanded ? null : TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                        ),
                      ),
                      if (!expanded && _isLong(parts.body))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Selengkapnya',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppColors.brandBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (post.questionnaire != null) ...[
                  const SizedBox(height: 12),
                  QuestionnaireCard(
                    info: post.questionnaire!,
                    closed: post.isClosed,
                  ),
                ],
                if (post.images.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  PostImageGallery(
                    images: post.images,
                    onTap: onImageTap ?? (_) => onOpen?.call(),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _VotePill(post: post, onVote: onVote),
                    const SizedBox(width: 8),
                    _PillButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: Fmt.count(post.commentCount),
                      tooltip: 'Komentar',
                      onTap: onOpen,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onSave,
                      tooltip: post.isSaved ? 'Hapus dari simpanan' : 'Simpan',
                      icon: Icon(
                        post.isSaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: post.isSaved ? AppColors.brandBlue : null,
                      ),
                    ),
                    IconButton(
                      onPressed: onShare,
                      tooltip: 'Bagikan',
                      icon: const Icon(Icons.share_outlined),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VotePill extends StatelessWidget {
  const _VotePill({required this.post, required this.onVote});

  final Post post;
  final ValueChanged<int>? onVote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final up = post.myVote == 1;
    final down = post.myVote == -1;
    final scoreColor = up
        ? AppColors.brandBlue
        : (down ? AppColors.error : theme.colorScheme.onSurface);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _VoteArrow(
            icon: Icons.arrow_upward_rounded,
            active: up,
            activeColor: AppColors.brandBlue,
            tooltip: 'Upvote',
            onTap: onVote == null ? null : () => onVote!(1),
          ),
          Text(
            Fmt.count(post.score),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: scoreColor,
            ),
          ),
          _VoteArrow(
            icon: Icons.arrow_downward_rounded,
            active: down,
            activeColor: AppColors.error,
            tooltip: 'Downvote',
            onTap: onVote == null ? null : () => onVote!(-1),
          ),
        ],
      ),
    );
  }
}

class _VoteArrow extends StatelessWidget {
  const _VoteArrow({
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final Color activeColor;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: active ? activeColor : null),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
