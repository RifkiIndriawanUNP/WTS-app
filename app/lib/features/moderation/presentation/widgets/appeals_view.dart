import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/report_repository.dart';
import '../../domain/moderation_action.dart';
import '../providers/report_providers.dart';
import 'report_case_card.dart';

/// Daftar banding. Moderator hanya membaca; admin bisa menerima/menolak.
class AppealsView extends ConsumerWidget {
  const AppealsView({super.key, required this.decided});

  final bool decided;

  Future<void> _open(BuildContext context, WidgetRef ref, Appeal a) async {
    final isAdmin = ref.read(authControllerProvider).user?.isAdmin ?? false;
    final result = await showGlassSheet<({bool accept, String note})>(
      context: context,
      builder: (ctx) => _AppealSheet(
        appeal: a,
        canDecide: isAdmin && a.status == AppealStatus.pending,
      ),
    );
    if (result == null || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(reportRepositoryProvider)
          .decideAppeal(
            appealId: a.id,
            accept: result.accept,
            note: result.note,
          );
      ref.invalidate(appealsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                result.accept ? 'Banding diterima' : 'Banding ditolak',
              ),
            ),
          );
      }
    } on ReportException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(appealsProvider(decided));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(e is ReportException ? e.message : 'Gagal memuat banding'),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Text(
              decided
                  ? 'Belum ada banding yang diputuskan'
                  : 'Tidak ada banding menunggu',
              style: theme.textTheme.titleMedium,
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final a = items[i];
            return GlassContainer(
              radius: 20,
              blur: 14,
              shadow: false,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _open(context, ref, a),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                a.accountLabel ?? 'Pengguna',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              Fmt.ago(a.createdAt),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          a.message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        ReportBadge(
                          a.status.label,
                          color: switch (a.status) {
                            AppealStatus.pending => AppColors.secondary,
                            AppealStatus.accepted => AppColors.success,
                            AppealStatus.rejected => AppColors.neutral,
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AppealSheet extends StatefulWidget {
  const _AppealSheet({required this.appeal, required this.canDecide});

  final Appeal appeal;
  final bool canDecide;

  @override
  State<_AppealSheet> createState() => _AppealSheetState();
}

class _AppealSheetState extends State<_AppealSheet> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.appeal;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        Text(
          'Banding ${a.accountLabel ?? ''}'.trim(),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SelectableText(a.message, style: theme.textTheme.bodyMedium),
        if (a.note != null) ...[
          const SizedBox(height: 10),
          Text('Jawaban admin: ${a.note}', style: theme.textTheme.bodySmall),
        ],
        if (widget.canDecide) ...[
          const SizedBox(height: 14),
          GlassTextArea(
            controller: _note,
            hintText: 'Jawaban untuk pengguna (opsional)',
            maxLength: ModerationRules.reasonMax,
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 14),
          GlassButton(
            label: 'Terima banding',
            onPressed: () =>
                Navigator.of(context)
                    .pop((accept: true, note: _note.text.trim())),
          ),
          const SizedBox(height: 8),
          GlassButton(
            label: 'Tolak banding',
            variant: GlassButtonVariant.danger,
            onPressed: () =>
                Navigator.of(context)
                    .pop((accept: false, note: _note.text.trim())),
          ),
        ] else ...[
          const SizedBox(height: 12),
          Text(
            a.status == AppealStatus.pending
                ? 'Hanya admin yang dapat memutuskan banding.'
                : 'Diputuskan ${a.decidedBy == null ? '' : 'oleh @${a.decidedBy}'}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
