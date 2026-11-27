import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/report_repository.dart';
import '../../domain/report.dart';
import '../../domain/report_case.dart';
import '../providers/report_providers.dart';
import '../widgets/report_case_card.dart';
import '../widgets/appeals_view.dart';
import 'report_detail_screen.dart';

/// Antrean laporan untuk moderator/admin: tab Menunggu | Selesai,
/// filter jenis konten, urut berdasarkan prioritas.
class ReportQueueScreen extends ConsumerStatefulWidget {
  const ReportQueueScreen({super.key});

  @override
  ConsumerState<ReportQueueScreen> createState() => _ReportQueueScreenState();
}

class _ReportQueueScreenState extends ConsumerState<ReportQueueScreen> {
  bool _handled = false;
  bool _appeals = false;
  ReportTarget? _target;

  QueueQuery get _query => (handled: _handled, target: _target);

  Future<void> _refresh() async {
    ref.invalidate(pendingReportCountProvider);
    ref.invalidate(reportQueueProvider(_query));
    await ref
        .read(reportQueueProvider(_query).future)
        .catchError((_) => <ReportCase>[]);
  }

  Future<void> _open(ReportCase item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ReportDetailScreen(caseId: item.id)),
    );
    if (mounted) {
      ref.invalidate(pendingReportCountProvider);
      ref.invalidate(reportQueueProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider.select((s) => s.user));
    final allowed = user != null && user.isModerator;
    final pending = allowed
        ? ref.watch(pendingReportCountProvider).asData?.value
        : null;
    final appealCount = allowed
        ? ref.watch(appealsProvider(false)).asData?.value.length
        : null;

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
                    'Antrean laporan',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (!allowed)
              const Expanded(
                child: Center(child: Text('Halaman ini khusus moderator')),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      GlassChip(
                        label: pending == null
                            ? 'Menunggu'
                            : 'Menunggu ($pending)',
                        selected: !_handled && !_appeals,
                        onTap: () => setState(() {
                          _handled = false;
                          _appeals = false;
                        }),
                      ),
                      const SizedBox(width: 8),
                      GlassChip(
                        label: 'Selesai',
                        selected: _handled && !_appeals,
                        onTap: () => setState(() {
                          _handled = true;
                          _appeals = false;
                        }),
                      ),
                      const SizedBox(width: 8),
                      GlassChip(
                        label: appealCount == null || appealCount == 0
                            ? 'Banding'
                            : 'Banding ($appealCount)',
                        selected: _appeals,
                        onTap: () => setState(() => _appeals = true),
                      ),
                    ],
                  ),
                ),
              ),
              if (_appeals)
                const SizedBox.shrink()
              else
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    children: [
                      GlassChip(
                        label: 'Semua',
                        selected: _target == null,
                        onTap: () => setState(() => _target = null),
                      ),
                      for (final t in ReportTarget.values) ...[
                        const SizedBox(width: 8),
                        GlassChip(
                          label:
                              t.label[0].toUpperCase() + t.label.substring(1),
                          selected: _target == t,
                          icon: reportTargetIcon(t),
                          onTap: () => setState(() => _target = t),
                        ),
                      ],
                    ],
                  ),
                ),
              Expanded(
                child: _appeals
                    ? const _AppealTabs()
                    : _QueueList(
                        query: _query,
                        onRefresh: _refresh,
                        onOpen: _open,
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QueueList extends ConsumerWidget {
  const _QueueList({
    required this.query,
    required this.onRefresh,
    required this.onOpen,
  });

  final QueueQuery query;
  final Future<void> Function() onRefresh;
  final void Function(ReportCase) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(reportQueueProvider(query));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                e is ReportException ? e.message : 'Gagal memuat antrean',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(reportQueueProvider(query)),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              children: [
                const SizedBox(height: 80),
                Icon(
                  Icons.verified_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  query.handled
                      ? 'Belum ada laporan yang selesai'
                      : 'Tidak ada laporan menunggu',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, i) =>
                ReportCaseCard(item: items[i], onTap: () => onOpen(items[i])),
          ),
        );
      },
    );
  }
}

/// Banding: menunggu dulu, lalu yang sudah diputuskan.
class _AppealTabs extends StatelessWidget {
  const _AppealTabs();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Text('Menunggu', style: theme.textTheme.labelLarge),
        ),
        const SizedBox(height: 360, child: AppealsView(decided: false)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Text('Sudah diputuskan', style: theme.textTheme.labelLarge),
        ),
        const SizedBox(height: 360, child: AppealsView(decided: true)),
      ],
    );
  }
}
