import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../shared/widgets/linkified_text.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../domain/comment.dart';

/// Daftar komentar berbentuk pohon (maks 3 tingkat). Balasan lebih dari satu
/// dilipat di bawah "Lihat N balasan lainnya". Status lipat dipegang pemanggil
/// ([expanded] + [onExpand]) supaya bisa dibuka otomatis setelah membalas.
class CommentTree extends StatelessWidget {
  const CommentTree({
    super.key,
    required this.nodes,
    required this.expanded,
    required this.onExpand,
    this.onVote,
    this.onReply,
    this.onMenu,
  });

  final List<CommentNode> nodes;

  /// Id komentar yang balasannya sudah dibuka penuh.
  final Set<String> expanded;
  final ValueChanged<String> onExpand;

  /// Arah suara 1 / -1 pada sebuah komentar.
  final void Function(Comment comment, int direction)? onVote;
  final ValueChanged<Comment>? onReply;
  final ValueChanged<Comment>? onMenu;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final node in nodes)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _Item(
              node: node,
              level: 0,
              expanded: expanded,
              onExpand: onExpand,
              tree: this,
            ),
          ),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.node,
    required this.level,
    required this.expanded,
    required this.onExpand,
    required this.tree,
  });

  final CommentNode node;
  final int level;
  final Set<String> expanded;
  final ValueChanged<String> onExpand;
  final CommentTree tree;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = node.comment;
    final widget = tree;
    final now = DateTime.now();

    final children = node.children;
    final collapsed = children.length > 1 && !expanded.contains(c.id);
    final shown = collapsed ? children.take(1).toList() : children;
    final hiddenCount = collapsed
        ? children.skip(1).fold<int>(0, (sum, n) => sum + 1 + n.descendantCount)
        : 0;

    final avatarSize = level == 0 ? 32.0 : 26.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(
              initials: c.authorInitials,
              imagePath: c.isAnonymousOp ? null : c.authorAvatar,
              size: avatarSize,
              glass: false,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(
                        c.authorLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (c.isOp) const _OpBadge(),
                      Text(
                        [
                          Fmt.ago(c.createdAt, now: now),
                          if (c.isEdited) 'Diedit',
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (c.isDeleted)
                    Text(
                      '[komentar dihapus]',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    LinkifiedText(
                      c.body ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  if (!c.isDeleted)
                    Row(
                      children: [
                        _MiniVote(comment: c, onVote: widget.onVote),
                        if (c.canReply && widget.onReply != null)
                          TextButton.icon(
                            onPressed: () => widget.onReply!(c),
                            icon: const Icon(Icons.reply_rounded, size: 16),
                            label: const Text('Balas'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor:
                                  theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        const Spacer(),
                        if (widget.onMenu != null)
                          IconButton(
                            onPressed: () => widget.onMenu!(c),
                            tooltip: 'Menu komentar',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.more_horiz_rounded,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        if (shown.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: avatarSize / 2 - 1, top: 4),
            child: Container(
              padding: EdgeInsets.only(left: avatarSize / 2 + 8),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final child in shown)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _Item(
                        node: child,
                        level: level + 1,
                        expanded: expanded,
                        onExpand: onExpand,
                        tree: tree,
                      ),
                    ),
                  if (collapsed)
                    InkWell(
                      onTap: () => onExpand(c.id),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add_circle_outline_rounded,
                              size: 16,
                              color: AppColors.brandBlue,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Lihat $hiddenCount balasan lainnya',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppColors.brandBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _OpBadge extends StatelessWidget {
  const _OpBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.brandBlue.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'OP',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: AppColors.brandBlue, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _MiniVote extends StatelessWidget {
  const _MiniVote({required this.comment, required this.onVote});

  final Comment comment;
  final void Function(Comment comment, int direction)? onVote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final up = comment.myVote == 1;
    final down = comment.myVote == -1;
    final color = up ? AppColors.brandBlue : (down ? AppColors.error : null);

    Widget arrow(
      IconData icon,
      bool active,
      Color activeColor,
      String tip,
      int dir,
    ) {
      return Semantics(
        button: true,
        label: tip,
        child: InkResponse(
          radius: 18,
          onTap: onVote == null ? null : () => onVote!(comment, dir),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 17, color: active ? activeColor : null),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        arrow(
          Icons.arrow_upward_rounded,
          up,
          AppColors.brandBlue,
          'Upvote komentar',
          1,
        ),
        Text(
          Fmt.count(comment.score),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        arrow(
          Icons.arrow_downward_rounded,
          down,
          AppColors.error,
          'Downvote komentar',
          -1,
        ),
      ],
    );
  }
}
