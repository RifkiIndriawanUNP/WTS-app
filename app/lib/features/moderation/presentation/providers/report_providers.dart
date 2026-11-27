import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../timeline/data/fake_post_repository.dart';
import '../../../timeline/presentation/providers/feed_providers.dart';
import '../../data/fake_report_repository.dart';
import '../../data/report_repository.dart';
import '../../domain/moderation_action.dart';
import '../../domain/report.dart';
import '../../domain/report_case.dart';

/// Ganti isi provider ini dengan implementasi Supabase saat backend siap.
final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => FakeReportRepository(
    currentUser: () => ref.read(authControllerProvider).user,
    // Repo palsu: tindakan moderasi menyembunyikan/memulihkan postingan di Home.
    onVisibilityChanged: (target, id, visible) {
      final posts = ref.read(postRepositoryProvider);
      if (target == ReportTarget.post && posts is FakePostRepository) {
        posts.setModerationHidden(id, hidden: !visible);
      }
    },
  ),
);

/// Kunci antrean: tab (menunggu/selesai) + filter jenis konten.
typedef QueueQuery = ({bool handled, ReportTarget? target});

final reportQueueProvider = FutureProvider.autoDispose
    .family<List<ReportCase>, QueueQuery>((ref, q) {
      return ref
          .watch(reportRepositoryProvider)
          .fetchQueue(handled: q.handled, target: q.target);
    });

final pendingReportCountProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(reportRepositoryProvider).pendingCount();
});

final reportCaseProvider = FutureProvider.autoDispose
    .family<ReportCase, String>((ref, id) {
      return ref.watch(reportRepositoryProvider).getCase(id);
    });

/// Banding: false = menunggu, true = sudah diputuskan.
final appealsProvider = FutureProvider.autoDispose.family<List<Appeal>, bool>((
  ref,
  decided,
) {
  return ref.watch(reportRepositoryProvider).fetchAppeals(decided: decided);
});
