import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wts/features/timeline/data/fake_post_repository.dart';
import 'package:wts/shared/widgets/widgets.dart';
import 'package:wts/features/timeline/data/post_repository.dart';
import 'package:wts/features/timeline/domain/post.dart';
import 'package:wts/features/timeline/presentation/providers/feed_providers.dart';
import 'package:wts/features/timeline/presentation/screens/home_tab.dart';
import 'package:wts/features/timeline/presentation/widgets/post_card.dart';

Post _post({
  String caption = 'Judul\nIsi postingan',
  int up = 0,
  int down = 0,
  int myVote = 0,
}) {
  final now = DateTime.now();
  return Post(
    id: 'x',
    caption: caption,
    tags: const [PostTag(id: 7, name: 'Akademik', slug: 'akademik')],
    createdAt: now.subtract(const Duration(minutes: 15)),
    expiresAt: now.add(const Duration(days: 10)),
    authorUsername: 'rina_putri',
    upvotes: up,
    downvotes: down,
    myVote: myVote,
  );
}

void main() {
  group('Post', () {
    test('caption dipecah menjadi judul dan isi', () {
      final p = _post(caption: 'Judul singkat\nIsi lengkap di sini');
      expect(p.parts.title, 'Judul singkat');
      expect(p.parts.body, 'Isi lengkap di sini');
      expect(_post(caption: 'Tanpa judul saja').parts.title, isNull);
      expect(_post(caption: 'Hanya baris\n').parts.title, isNull);
    });

    test('withVote menghitung ulang upvote/downvote', () {
      var p = _post(up: 5, down: 1);
      p = p.withVote(1);
      expect((p.upvotes, p.downvotes, p.score), (6, 1, 5));
      p = p.withVote(-1);
      expect((p.upvotes, p.downvotes, p.myVote), (5, 2, -1));
      p = p.withVote(0);
      expect((p.upvotes, p.downvotes, p.myVote), (5, 1, 0));
    });

    test('anonim tidak menampilkan username', () {
      final now = DateTime.now();
      final p = Post(
        id: 'a',
        caption: 'x',
        tags: const [],
        createdAt: now,
        expiresAt: now,
        isAnonymous: true,
      );
      expect(p.authorLabel, 'Anonim');
      expect(p.authorInitials, '?');
    });
  });

  group('FakePostRepository', () {
    late FakePostRepository repo;
    setUp(
      () => repo = FakePostRepository(
        currentUser: () => null,
        latency: Duration.zero,
      ),
    );

    test('pengumuman resmi selalu di atas', () async {
      for (final sort in PostSort.values) {
        final page = await repo.fetchFeed(sort: sort);
        expect(page.items.first.isOfficial, isTrue, reason: sort.name);
      }
    });

    test('filter tag dan paginasi', () async {
      final tagged = await repo.fetchFeed(sort: PostSort.newest, tagId: 9);
      expect(tagged.items, isNotEmpty);
      expect(tagged.items.every((p) => p.tags.any((t) => t.id == 9)), isTrue);

      final first = await repo.fetchFeed(sort: PostSort.newest, limit: 5);
      final second = await repo.fetchFeed(
        sort: PostSort.newest,
        offset: 5,
        limit: 5,
      );
      expect(first.hasMore, isTrue);
      expect(
        first.items
            .map((p) => p.id)
            .toSet()
            .intersection(second.items.map((p) => p.id).toSet()),
        isEmpty,
      );
    });

    test('sortir komentar dan segera berakhir', () async {
      final byComments = (await repo.fetchFeed(
        sort: PostSort.mostCommented,
        limit: 50,
      )).items;
      final normal = byComments.where((p) => !p.isOfficial).toList();
      for (var i = 1; i < normal.length; i++) {
        expect(normal[i - 1].commentCount >= normal[i].commentCount, isTrue);
      }
      final ending = (await repo.fetchFeed(
        sort: PostSort.endingSoon,
        limit: 50,
      )).items.where((p) => !p.isOfficial).toList();
      for (var i = 1; i < ending.length; i++) {
        expect(!ending[i - 1].expiresAt.isAfter(ending[i].expiresAt), isTrue);
      }
    });

    test('vote berubah, tidak bisa vote postingan sendiri', () async {
      final voted = await repo.setVote('p4', 1);
      expect(voted.myVote, 1);
      await expectLater(
        repo.setVote('p11', 1),
        throwsA(
          isA<PostException>().having((e) => e.code, 'code', 'own_content'),
        ),
      );
    });

    test('simpan dan batal simpan', () async {
      expect(await repo.toggleSave('p4'), isTrue);
      expect(await repo.toggleSave('p4'), isFalse);
    });

    test('11 tag linimasa tersedia', () async {
      expect((await repo.fetchTags()).length, 11);
    });
  });

  group('Tampilan', () {
    testWidgets('PostCard menampilkan judul, tag, dan memanggil onVote', (
      tester,
    ) async {
      int? voted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostCard(post: _post(up: 42), onVote: (d) => voted = d),
            ),
          ),
        ),
      );
      expect(find.text('Judul'), findsOneWidget);
      expect(find.text('Isi postingan'), findsOneWidget);
      expect(find.text('Akademik'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      expect(voted, 1);
    });

    testWidgets('HomeTab memuat feed dan menyaring tag', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            postRepositoryProvider.overrideWithValue(
              FakePostRepository(
                currentUser: () => null,
                latency: Duration.zero,
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: HomeTab())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Want to Share'), findsOneWidget);
      expect(find.text('Pengumuman: Jadwal UTS Genap'), findsOneWidget);

      await tester.tap(find.widgetWithText(GlassChip, 'Organisasi'));
      await tester.pumpAndSettle();
      expect(find.text('Pengumuman: Jadwal UTS Genap'), findsNothing);
      expect(find.text('Open recruitment BEM periode baru'), findsOneWidget);
    });
  });
}
