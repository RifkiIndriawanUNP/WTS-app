import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wts/features/timeline/data/fake_post_repository.dart';
import 'package:wts/features/timeline/domain/post.dart';
import 'package:wts/features/timeline/domain/post_filter.dart';
import 'package:wts/features/timeline/presentation/providers/feed_providers.dart';
import 'package:wts/features/timeline/presentation/screens/home_tab.dart';

void main() {
  group('PostFilter', () {
    test('bawaan tidak aktif', () {
      const f = PostFilter();
      expect(f.isActive, isFalse);
      expect(f.activeCount, 0);
    });

    test('activeCount menghitung tiap pengaturan', () {
      const f = PostFilter(
        range: PostTimeRange.week,
        onlyWithImages: true,
        hideClosed: true,
      );
      expect(f.activeCount, 3);
      expect(f.copyWith(range: PostTimeRange.all).activeCount, 2);
    });

    test('kesamaan berdasarkan nilai', () {
      expect(
        const PostFilter(range: PostTimeRange.day),
        const PostFilter().copyWith(range: PostTimeRange.day),
      );
      expect(const PostFilter(), isNot(const PostFilter(hideClosed: true)));
    });
  });

  group('Filter di repo palsu', () {
    late FakePostRepository repo;
    setUp(
      () => repo = FakePostRepository(
        currentUser: () => null,
        latency: Duration.zero,
      ),
    );

    Future<List<Post>> fetch(PostFilter f, {int? tagId, String? query}) async {
      final page = await repo.fetchFeed(
        sort: PostSort.newest,
        filter: f,
        tagId: tagId,
        query: query,
        limit: 50,
      );
      return page.items;
    }

    test('24 jam hanya yang baru', () async {
      final items = await fetch(const PostFilter(range: PostTimeRange.day));
      final ids = items.map((p) => p.id);
      expect(ids, contains('p2'));
      expect(ids, isNot(contains('p7')));
      expect(ids, isNot(contains('p11')));
    });

    test('7 hari membuang yang lebih lama', () async {
      final items = await fetch(const PostFilter(range: PostTimeRange.week));
      final ids = items.map((p) => p.id);
      expect(ids, contains('p13'));
      expect(ids, isNot(contains('p14')));
    });

    test('hanya yang ada gambar', () async {
      final items = await fetch(const PostFilter(onlyWithImages: true));
      expect(items, isNotEmpty);
      expect(items.every((p) => p.images.isNotEmpty), isTrue);
      expect(items.any((p) => p.id == 'p1'), isFalse);
    });

    test('sembunyikan yang sudah selesai', () async {
      final all = await fetch(const PostFilter());
      final shown = await fetch(const PostFilter(hideClosed: true));
      expect(all.any((p) => p.id == 'p10'), isTrue);
      expect(shown.any((p) => p.id == 'p10'), isFalse);
      expect(shown.every((p) => !p.isClosed), isTrue);
    });

    test('bisa digabung dengan tag dan pencarian', () async {
      final items = await fetch(
        const PostFilter(onlyWithImages: true, range: PostTimeRange.day),
        query: 'bem',
      );
      expect(items.map((p) => p.id), contains('p6'));
      expect(items.every((p) => p.images.isNotEmpty), isTrue);
    });
  });

  group('FeedController', () {
    test(
      'setFilter memuat ulang dengan filter dan resetFilters mengosongkannya',
      () async {
        final container = ProviderContainer(
          overrides: [
            postRepositoryProvider.overrideWithValue(
              FakePostRepository(
                currentUser: () => null,
                latency: Duration.zero,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.read(feedControllerProvider);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final controller = container.read(feedControllerProvider.notifier);
        await controller.setFilter(const PostFilter(onlyWithImages: true));
        var state = container.read(feedControllerProvider);
        expect(state.filter.onlyWithImages, isTrue);
        expect(state.items, isNotEmpty);
        expect(state.items.every((p) => p.images.isNotEmpty), isTrue);

        await controller.selectTag(3);
        await controller.resetFilters();
        state = container.read(feedControllerProvider);
        expect(state.filter.isActive, isFalse);
        expect(state.tagId, isNull);
        expect(state.items.any((p) => p.images.isEmpty), isTrue);
      },
    );
  });

  group('Tombol Filter di Home', () {
    Widget app() => ProviderScope(
      overrides: [
        postRepositoryProvider.overrideWithValue(
          FakePostRepository(currentUser: () => null, latency: Duration.zero),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: HomeTab())),
    );

    void bigScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets(
      'terapkan filter -> daftar berubah dan penanda muncul, reset menghapusnya',
      (tester) async {
        bigScreen(tester);
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(find.text('Pengumuman: Jadwal UTS Genap'), findsOneWidget);
        expect(find.byKey(const ValueKey('filter_badge')), findsNothing);

        await tester.tap(find.byIcon(Icons.tune_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Filter postingan'), findsOneWidget);

        await tester.tap(find.text('Hanya yang ada gambar'));
        await tester.pump();
        await tester.tap(find.text('Terapkan (1)'));
        await tester.pumpAndSettle();

        expect(find.text('Pengumuman: Jadwal UTS Genap'), findsNothing);
        expect(find.text('Open recruitment BEM periode baru'), findsOneWidget);
        expect(find.byKey(const ValueKey('filter_badge')), findsOneWidget);

        await tester.tap(find.byIcon(Icons.tune_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reset'));
        await tester.pump();
        await tester.tap(find.text('Terapkan'));
        await tester.pumpAndSettle();

        expect(find.text('Pengumuman: Jadwal UTS Genap'), findsOneWidget);
        expect(find.byKey(const ValueKey('filter_badge')), findsNothing);
      },
    );

    testWidgets('menutup sheet tanpa menerapkan tidak mengubah apa pun', (
      tester,
    ) async {
      bigScreen(tester);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hanya yang ada gambar'));
      await tester.pump();
      await tester.tapAt(
        const Offset(10, 10),
      ); // tutup dengan mengetuk area gelap
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('filter_badge')), findsNothing);
      expect(find.text('Pengumuman: Jadwal UTS Genap'), findsOneWidget);
    });
  });
}
