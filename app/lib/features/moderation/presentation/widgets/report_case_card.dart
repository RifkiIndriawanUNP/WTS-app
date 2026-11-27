import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/report.dart';
import '../../domain/report_case.dart';

IconData reportTargetIcon(ReportTarget t) => switch (t) {
  ReportTarget.post => Icons.article_outlined,
  ReportTarget.comment => Icons.chat_bubble_outline_rounded,
  ReportTarget.product => Icons.sell_outlined,
  ReportTarget.user => Icons.person_outline_rounded,
  ReportTarget.message => Icons.mail_outline_rounded,
};

/// Lencana kecil berwarna (Prioritas, Disembunyikan otomatis, status).
class ReportBadge extends StatelessWidget {
  const ReportBadge(
    this.label, {
    super.key,
    this.color = AppColors.neutral,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge status kasus (menunggu / ditindak / diabaikan).
Widget reportStatusBadge(ReportStatus s) => ReportBadge(
  s.label,
  color: switch (s) {
    ReportStatus.pending => AppColors.secondary,
    ReportStatus.resolved => AppColors.success,
    ReportStatus.dismissed => AppColors.neutral,
  },
);

/// Kartu satu kasus di antrean.
class ReportCaseCard extends StatelessWidget {
  const ReportCaseCard({super.key, required this.item, required this.onTap});

  final ReportCase item;
  final VoidCallback onTap;

  String get _preview {
    final c = item.content;
    final head = c.title;
    final body = c.body.trim();
    if (head != null && head.isNotEmpty) {
      return body.isEmpty ? head : '$head\n$body';
    }
    return body;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final c = item.content;
    final author = c.isAnonymous
        ? 'Anonim'
        : (c.authorUsername == null ? null : '@${c.authorUsername}');

    return Semantics(
      button: true,
      label: 'Laporan ${item.target.label}',
      child: GlassContainer(
        radius: 20,
        blur: 14,
        shadow: false,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        reportTargetIcon(item.target),
                        size: 18,
                        color: muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.target.label[0].toUpperCase() +
                            item.target.label.substring(1),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        Fmt.ago(item.lastReportedAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _preview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (author != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      author,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ReportBadge(
                        '${item.reportCount} laporan',
                        color: AppColors.navy,
                        icon: Icons.flag_outlined,
                      ),
                      ReportBadge(item.topReason.label),
                      if (!item.status.isHandled && item.isSevere)
                        const ReportBadge('Prioritas', color: AppColors.error),
                      if (item.autoHidden)
                        const ReportBadge(
                          'Disembunyikan otomatis',
                          color: Color(0xFFD97706),
                          icon: Icons.visibility_off_outlined,
                        ),
                      if (item.status.isHandled) reportStatusBadge(item.status),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
