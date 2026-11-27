import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/utils/links.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/link_launcher.dart';
import '../../domain/post.dart';

/// Kartu khusus untuk postingan bertag Kuesioner: tujuan tautan, batas waktu,
/// estimasi durasi, dan tombol "Isi Kuesioner" (membuka tautan setelah konfirmasi).
class QuestionnaireCard extends StatelessWidget {
  const QuestionnaireCard({super.key, required this.info, this.closed = false});

  final QuestionnaireInfo info;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final deadline = info.deadline;
    final over = deadline != null && deadline.isBefore(DateTime.now());
    final disabled = closed || over;

    final facts = <String>[
      if (deadline != null)
        (over ? 'Batas waktu lewat' : 'Batas ${Fmt.date(deadline)}'),
      if (info.durationMin != null) '±${info.durationMin} menit',
    ];

    return GlassContainer(
      radius: 20,
      blur: 10,
      shadow: false,
      tint: AppColors.secondary,
      tintOpacity: 0.12,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.assignment_outlined, color: AppColors.brandBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Links.host(info.link),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (facts.isNotEmpty)
                  Text(
                    facts.join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: disabled
                ? null
                : () => openLinkWithConfirm(context, info.link),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Text('Isi Kuesioner'),
          ),
        ],
      ),
    );
  }
}
