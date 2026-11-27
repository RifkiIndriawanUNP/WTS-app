import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../timeline/presentation/providers/feed_providers.dart';
import '../../data/report_repository.dart';
import '../../domain/moderation_action.dart';
import '../../domain/report_case.dart';
import '../providers/report_providers.dart';
import '../widgets/moderation_action_sheet.dart';
import '../widgets/report_case_card.dart';

/// Detail satu kasus: isi konten (salinan), ringkasan alasan, catatan
/// pelapor (tanpa identitas), dan riwayat pelanggaran terlapor.
class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(reportCaseProvider(caseId));

    return GlassScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Kembali',
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Text(
                    'Detail laporan',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    e is ReportException ? e.message : 'Gagal memuat laporan',
                  ),
                ),
                data: (item) => _Body(item: item),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.item});

  final ReportCase item;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;

  ReportCase get item => widget.item;

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _act(ModerationAction action) async {
    if (_busy) {
      return;
    }
    final reason = await showModerationActionSheet(context, action);
    if (reason == null || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(reportRepositoryProvider)
          .moderate(caseId: item.id, action: action, reason: reason);
      ref.invalidate(reportCaseProvider(item.id));
      ref.invalidate(pendingReportCountProvider);
      ref.invalidate(reportQueueProvider);
      ref.invalidate(feedControllerProvider); // Home ikut menyesuaikan
      if (mounted) {
        _snack('Tindakan dicatat: ${action.label}');
      }
    } on ReportException catch (e) {
      if (mounted) {
        _snack(e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _reveal() async {
    final ok = await showGlassConfirm(
      context,
      title: 'Buka identitas penulis?',
      message: 'Hanya untuk penegakan aturan. Akses ini tercatat di audit log atas namamu.',
      confirmLabel: 'Buka identitas',
      destructive: true,
    );
    if (ok != true || !mounted) {
      return;
    }
    try {
      final name = await ref
          .read(reportRepositoryProvider)
          .revealAuthor(item.id);
      if (mounted) {
        await showGlassMessage(
          context,
          title: 'Penulis anonim',
          message: '@$name',
        );
      }
    } on ReportException catch (e) {
      if (mounted) {
        _snack(e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(
      authControllerProvider.select((s) => s.user?.isAdmin ?? false),
    );
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final c = item.content;
    final reasons = item.reasons.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            reportStatusBadge(item.status),
            ReportBadge(
              item.target.label[0].toUpperCase() +
                  item.target.label.substring(1),
              icon: reportTargetIcon(item.target),
            ),
            if (item.isSevere && !item.status.isHandled)
              const ReportBadge('Prioritas', color: AppColors.error),
            if (item.autoHidden)
              const ReportBadge(
                'Disembunyikan otomatis',
                color: Color(0xFFD97706),
                icon: Icons.visibility_off_outlined,
              ),
          ],
        ),
        const _Label('Konten yang dilaporkan'),
        _Panel(
          children: [
            if (c.isAnonymous)
              Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 16, color: muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Anonim - identitas hanya dapat dibuka admin',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: muted,
                      ),
                    ),
                  ),
                  if (isAdmin)
                    TextButton(
                      onPressed: _reveal,
                      child: const Text('Buka identitas'),
                    ),
                ],
              )
            else if (c.authorUsername != null)
              Text(
                '@${c.authorUsername}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (c.title != null) ...[
              const SizedBox(height: 8),
              Text(c.title!, style: theme.textTheme.titleMedium),
            ],
            if (c.body.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(c.body, style: theme.textTheme.bodyMedium),
            ],
            if (c.meta != null) ...[
              const SizedBox(height: 8),
              Text(c.meta!, style: theme.textTheme.labelLarge),
            ],
            if (c.imageCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.image_outlined, size: 16, color: muted),
                  const SizedBox(width: 6),
                  Text(
                    '${c.imageCount} gambar',
                    style: theme.textTheme.labelMedium?.copyWith(color: muted),
                  ),
                ],
              ),
            ],
            if (c.lines.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Percakapan sebelumnya',
                style: theme.textTheme.labelMedium?.copyWith(color: muted),
              ),
              const SizedBox(height: 4),
              for (final l in c.lines)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(l, style: theme.textTheme.bodySmall),
                ),
            ],
            if (c.createdAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Dibuat ${Fmt.ago(c.createdAt!)}',
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
            ],
            if (!c.available) ...[
              const SizedBox(height: 8),
              Text(
                'Konten sudah tidak tampil di aplikasi. Ini salinan saat dilaporkan.',
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
            ],
          ],
        ),
        const _Label('Ringkasan laporan'),
        _Panel(
          children: [
            Text(
              '${item.reportCount} pelapor - pertama ${Fmt.ago(item.firstReportedAt)}, '
              'terakhir ${Fmt.ago(item.lastReportedAt)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            for (final e in reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.key.label,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Text('${e.value}', style: theme.textTheme.labelLarge),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: e.value / item.reportCount,
                        minHeight: 6,
                        backgroundColor: AppColors.neutral.withValues(
                          alpha: 0.15,
                        ),
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (item.notes.isNotEmpty) ...[
          const _Label('Catatan pelapor (tanpa identitas)'),
          _Panel(
            children: [
              for (final n in item.notes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('"$n"', style: theme.textTheme.bodyMedium),
                ),
            ],
          ),
        ],
        const _Label('Riwayat terlapor'),
        _Panel(
          children: [
            Text(
              item.priorViolations == 0
                  ? 'Belum pernah ditindak sebelumnya'
                  : 'Pernah ditindak ${item.priorViolations} kali sebelumnya',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        if (item.status.isHandled) ...[
          const _Label('Penanganan'),
          _Panel(
            children: [
              if (item.action != null)
                Text(item.action!.label, style: theme.textTheme.titleSmall),
              if (item.actionNote != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                  child: Text(
                    'Alasan: ${item.actionNote}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              Text(
                '${item.status.label}'
                '${item.handledBy == null ? '' : ' oleh @${item.handledBy}'}'
                '${item.handledAt == null ? '' : ' - ${Fmt.ago(item.handledAt!)}'}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ] else ...[
          const _Label('Tindakan'),
          _Panel(
            children: [
              for (final a in ModerationAction.values)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  enabled: !_busy && (!a.adminOnly || isAdmin),
                  leading: Icon(
                    a.adminOnly && !isAdmin
                        ? Icons.lock_outline_rounded
                        : _iconFor(a),
                    color: a.destructive ? AppColors.error : null,
                  ),
                  title: Text(a.label),
                  subtitle: a.adminOnly && !isAdmin
                      ? const Text('Khusus admin')
                      : null,
                  onTap: () => _act(a),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

IconData _iconFor(ModerationAction a) => switch (a) {
  ModerationAction.dismiss => Icons.check_circle_outline_rounded,
  ModerationAction.hide => Icons.visibility_off_outlined,
  ModerationAction.delete => Icons.delete_outline_rounded,
  ModerationAction.warn => Icons.warning_amber_rounded,
  ModerationAction.ban => Icons.block_rounded,
  _ => Icons.pause_circle_outline_rounded,
};

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: 20,
      blur: 14,
      shadow: false,
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}
