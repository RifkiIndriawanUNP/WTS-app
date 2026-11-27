import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wts/features/timeline/data/fake_post_repository.dart';
import 'package:wts/features/timeline/data/search_history_store.dart';
import 'package:wts/features/timeline/domain/post.dart';
import 'package:wts/features/timeline/presentation/providers/feed_providers.dart';
import 'package:wts/features/timeline/presentation/screens/post_search_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Pencarian (repo palsu)', () {
    late FakePostRepository repo;
    setUp(
      () => repo = FakePostRepository(
        currentUser: () => null,
        latency: Duration.zero,
      ),
    );

    Future<List<String>> ids(
      String q, {
      PostSort sort = PostSort.newest,
    }) async {
      final page = await repo.fetchFeed(sort: sort, query: q, limit: 50);
      return [for (final p in page.items) p.id];
    }

    test(
      'mencocokkan isi postingan tanpa membedakan huruf besar/kecil',
      () async {
        expect(await ids('KUESIONER SKRIPSI'), contains('p3'));
        expect(await ids('jas lab'), ['p4']);
      },
    );

    test('mencocokkan nama tag', () async {
      final byTag = await ids('Organisasi');
      expect(byTag, contains('p6'));
    });

    test('semua kata harus cocok', () async {
      expect(await ids('jas lab ukuran'), ['p4']);
      expect(await ids('jas lab tidak-ada-kata-ini'), isEmpty);
    });

    test('kata kunci tak dikenal -> kosong dan tanpa lanjutan', () async {
      final page = await repo.fetchFeed(sort: PostSort.newest, query: 'zzzxyz');
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('query kosong/spasi sama dengan tanpa pencarian', () async {
      final all = await repo.fetchFeed(sort: PostSort.newest, limit: 50);
      final blank = await repo.fetchFeed(
        sort: PostSort.newest,
        query: '   ',
        limit: 50,
      );
      expect(blank.items.length, all.items.length);
    });

    test('bisa digabung dengan filter tag dan urutan', () async {
      final page = await repo.fetchFeed(
        sort: PostSort.top,
        tagId: 1,
        query: 'kuesioner',
        limit: 50,
      );
      expect(page.items, isNotEmpty);
      expect(page.items.every((p) => p.tags.any((t) => t.id == 1)), isTrue);
    });

    test('postingan kedaluwarsa dan dihapus tidak muncul', () async {
      await repo.deletePost('p11');
      expect(await ids('praktikum jaringan'), isEmpty);
    });
  });

  group('SearchHistoryStore', () {
    const store = SearchHistoryStore();

    test('terbaru dulu, tanpa duplikat, maksimal 8', () async {
      await store.add('kalkulus');
      await store.add('jas lab');
      await store.add('KALKULUS');
      expect(await store.load(), ['KALKULUS', 'jas lab']);

      for (var i = 0; i < 12; i++) {
        await store.add('cari $i');
      }
      final list = await store.load();
      expect(list.length, SearchHistoryStore.maxItems);
      expect(list.first, 'cari 11');
    });

    test(
      'kata terlalu pendek tidak disimpan; hapus satu dan hapus semua',
      () async {
        await store.add('a');
        expect(await store.load(), isEmpty);
        await store.add('kuesioner');
        await store.add('magang');
        expect(await store.remove('kuesioner'), ['magang']);
        await store.clear();
        expect(await store.load(), isEmpty);
      },
    );
  });

  group('Layar pencarian', () {
    late FakePostRepository posts;
    setUp(
      () => posts = FakePostRepository(
        currentUser: () => null,
        latency: Duration.zero,
      ),
    );

    Widget app({String? initial}) => ProviderScope(
      overrides: [postRepositoryProvider.overrideWithValue(posts)],
      child: MaterialApp(home: PostSearchScreen(initialQuery: initial)),
    );

    void bigScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('kolom kosong menampilkan pintasan kategori', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Cari berdasarkan kategori'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Kuesioner'), findsOneWidget);
    });

    testWidgets('satu huruf meminta minimal dua huruf', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app());
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump();
      expect(find.text('Ketik minimal 2 huruf'), findsOneWidget);
    });

    testWidgets('mengetik menampilkan hasil setelah jeda', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app());
      await tester.enterText(find.byType(TextField), 'jas lab');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Hasil untuk “jas lab”'), findsOneWidget);
      expect(find.textContaining('Cari jas lab ukuran M'), findsOneWidget);
    });

    testWidgets('tanpa hasil menampilkan pesan kosong', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app());
      await tester.enterText(find.byType(TextField), 'zzzxyz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Tidak ada hasil untuk “zzzxyz”'), findsOneWidget);
    });

    testWidgets('mengosongkan kolom kembali ke pintasan', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app());
      await tester.enterText(find.byType(TextField), 'jas lab');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Cari berdasarkan kategori'), findsOneWidget);
    });

    testWidgets('pintasan tag mencari dan menyimpan riwayat', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ActionChip, 'Kuesioner'));
      await tester.pumpAndSettle();
      expect(find.text('Hasil untuk “Kuesioner”'), findsOneWidget);
      expect(await tester.runAsync(const SearchHistoryStore().load), [
        'Kuesioner',
      ]);
    });

    testWidgets('riwayat tampil dan bisa dipakai ulang', (tester) async {
      bigScreen(tester);
      SharedPreferences.setMockInitialValues({
        'wts.search_history': ['jas lab', 'magang'],
      });
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text('Pencarian terakhir'), findsOneWidget);
      expect(find.text('magang'), findsOneWidget);

      await tester.tap(find.text('jas lab'));
      await tester.pumpAndSettle();
      expect(find.text('Hasil untuk “jas lab”'), findsOneWidget);
    });

    testWidgets('Hapus semua mengosongkan riwayat', (tester) async {
      bigScreen(tester);
      SharedPreferences.setMockInitialValues({
        'wts.search_history': ['jas lab'],
      });
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hapus semua'));
      await tester.pumpAndSettle();
      expect(find.text('Pencarian terakhir'), findsNothing);
    });

    testWidgets('kata kunci awal langsung dicari', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app(initial: 'kuesioner'));
      await tester.pumpAndSettle();
      expect(find.text('Hasil untuk “kuesioner”'), findsOneWidget);
    });
  });
}
