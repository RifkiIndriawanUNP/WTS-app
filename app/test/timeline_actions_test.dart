import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wts/features/moderation/data/fake_report_repository.dart';
import 'package:wts/features/moderation/data/report_repository.dart';
import 'package:wts/features/moderation/domain/report.dart';
import 'package:wts/features/moderation/presentation/providers/report_providers.dart';
import 'package:wts/features/moderation/presentation/widgets/report_sheet.dart';
import 'package:wts/features/timeline/data/fake_post_repository.dart';
import 'package:wts/features/timeline/data/post_repository.dart';
import 'package:wts/features/timeline/domain/post.dart';
import 'package:wts/features/timeline/presentation/providers/feed_providers.dart';
import 'package:wts/features/timeline/presentation/widgets/post_share.dart';

void main() {
  group('Aksi pemilik (repo palsu)', () {
    late FakePostRepository repo;
    setUp(
      () => repo = FakePostRepository(
        currentUser: () => null,
        latency: Duration.zero,
      ),
    );

    test('tandai selesai hanya untuk pemilik', () async {
      final closed = await repo.closePost('p11');
      expect(closed.isClosed, isTrue);
      await expectLater(
        repo.closePost('p4'),
        throwsA(
          isA<PostException>().having((e) => e.code, 'code', 'forbidden'),
        ),
      );
    });

    test('hapus hanya untuk pemilik dan hilang dari feed', () async {
      await repo.deletePost('p11');
      final all = await repo.fetchFeed(sort: PostSort.newest, limit: 50);
      expect(all.items.any((p) => p.id == 'p11'), isFalse);
      await expectLater(repo.deletePost('p4'), throwsA(isA<PostException>()));
    });
  });

  group('Laporan', () {
    test('laporan ganda ditolak', () async {
      final repo = FakeReportRepository(latency: Duration.zero);
      await repo.submit(
        target: ReportTarget.post,
        targetId: 'p4',
        reason: ReportReason.spam,
      );
      await expectLater(
        repo.submit(
          target: ReportTarget.post,
          targetId: 'p4',
          reason: ReportReason.scam,
        ),
        throwsA(
          isA<ReportException>().having(
            (e) => e.code,
            'code',
            'already_reported',
          ),
        ),
      );
      expect(repo.count, 1);
    });

    test('nilai enum alasan sesuai database', () {
      expect(ReportReason.prohibitedItem.dbValue, 'prohibited_item');
      expect(ReportReason.hate.dbValue, 'hate');
      expect(ReportReason.values.length, 9);
    });

    testWidgets('sheet laporan: pilih alasan lalu kirim', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = FakeReportRepository(latency: Duration.zero);
      var sent = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [reportRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    sent = await showReportSheet(
                      context,
                      target: ReportTarget.post,
                      targetId: 'p4',
                    );
                  },
                  child: const Text('buka'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Spam atau promosi berlebihan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kirim laporan'));
      await tester.pumpAndSettle();

      expect(sent, isTrue);
      expect(repo.count, 1);
    });
  });

  group('Feed controller', () {
    test('hapus dan tandai selesai memperbarui daftar', () async {
      final container = ProviderContainer(
        overrides: [
          postRepositoryProvider.overrideWithValue(
            FakePostRepository(currentUser: () => null, latency: Duration.zero),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(feedControllerProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final ctrl = container.read(feedControllerProvider.notifier);
      await ctrl.loadMore(); // p11 ada di halaman kedua
      var mine = container
          .read(feedControllerProvider)
          .items
          .firstWhere((p) => p.id == 'p11');
      await ctrl.closePost(mine);
      mine = container
          .read(feedControllerProvider)
          .items
          .firstWhere((p) => p.id == 'p11');
      expect(mine.isClosed, isTrue);

      await ctrl.deletePost(mine);
      expect(
        container.read(feedControllerProvider).items.any((p) => p.id == 'p11'),
        isFalse,
      );

      await ctrl.setSort(PostSort.top);
      expect(container.read(feedControllerProvider).sort, PostSort.top);
    });
  });

  test('teks bagikan berisi penulis, cuplikan, dan tautan', () {
    final now = DateTime.now();
    final p = Post(
      id: 'abc',
      caption: 'Halo dunia',
      tags: const [],
      createdAt: now,
      expiresAt: now,
      authorUsername: 'rina_putri',
    );
    final text = postShareText(p);
    expect(text, contains('@rina_putri'));
    expect(text, contains('Halo dunia'));
    expect(text, contains('wts://post/abc'));
  });
}
