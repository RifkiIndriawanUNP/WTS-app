import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wts/features/auth/domain/user_profile.dart';
import 'package:wts/features/comments/data/comment_repository.dart';
import 'package:wts/features/comments/data/fake_comment_repository.dart';
import 'package:wts/features/comments/presentation/providers/comment_providers.dart';
import 'package:wts/features/timeline/data/fake_post_repository.dart';
import 'package:wts/features/timeline/presentation/providers/feed_providers.dart';
import 'package:wts/features/timeline/presentation/screens/post_detail_screen.dart';

final _user = UserProfile(
  id: 'u1',
  email: 'saya@nusaputra.ac.id',
  username: 'saya_mhs',
  createdAt: DateTime(2026, 1, 1),
);

Matcher _code(String code) =>
    isA<CommentException>().having((e) => e.code, 'code', code);

void main() {
  late FakePostRepository posts;
  late FakeCommentRepository repo;
  late List<int> deltas;

  setUp(() {
    deltas = [];
    posts = FakePostRepository(
      currentUser: () => _user,
      latency: Duration.zero,
    );
    repo = FakeCommentRepository(
      postLookup: posts.getPost,
      currentUser: () => _user,
      onCountChanged: (id, d) {
        deltas.add(d);
        posts.applyCommentDelta(id, d);
      },
      latency: Duration.zero,
    );
  });

  group('createComment', () {
    test('komentar utama ditambahkan dan jumlah bertambah', () async {
      final before = (await posts.getPost('p2')).commentCount;
      final c = await repo.createComment(postId: 'p2', body: '  halo  ');
      expect(c.body, 'halo');
      expect(c.isMine, isTrue);
      expect(c.depth, 0);
      expect(deltas, [1]);
      expect((await posts.getPost('p2')).commentCount, before + 1);
      final list = await repo.fetchComments('p2');
      expect(list.any((x) => x.id == c.id), isTrue);
    });

    test('isi kosong / terlalu panjang ditolak', () async {
      await expectLater(
        repo.createComment(postId: 'p2', body: '   '),
        throwsA(_code('invalid_body')),
      );
      await expectLater(
        repo.createComment(postId: 'p2', body: 'a' * 1001),
        throwsA(_code('invalid_body')),
      );
    });

    test('balasan naik satu tingkat dan batas tiga tingkat dijaga', () async {
      final root = await repo.createComment(postId: 'p2', body: 'a');
      final r1 = await repo.createComment(
        postId: 'p2',
        body: 'b',
        parentId: root.id,
      );
      final r2 = await repo.createComment(
        postId: 'p2',
        body: 'c',
        parentId: r1.id,
      );
      expect(r1.depth, 1);
      expect(r2.depth, 2);
      await expectLater(
        repo.createComment(postId: 'p2', body: 'd', parentId: r2.id),
        throwsA(_code('max_depth')),
      );
    });

    test('membalas komentar yang tidak ada -> not_found', () async {
      await repo.fetchComments('p2');
      await expectLater(
        repo.createComment(postId: 'p2', body: 'x', parentId: 'nope'),
        throwsA(_code('not_found')),
      );
    });

    test('postingan sudah selesai -> comments_closed', () async {
      await posts.closePost('p15');
      await expectLater(
        repo.createComment(postId: 'p15', body: 'x'),
        throwsA(_code('comments_closed')),
      );
    });

    test(
      'OP: pemilik postingan ditandai OP; anonim menyembunyikan nama',
      () async {
        final c = await repo.createComment(postId: 'p15', body: 'dari OP');
        expect(c.isOp, isTrue);
        final other = await repo.createComment(postId: 'p2', body: 'bukan OP');
        expect(other.isOp, isFalse);
        expect(other.authorUsername, 'saya_mhs');
      },
    );

    test('tanpa pengguna masuk -> forbidden', () async {
      final anon = FakeCommentRepository(
        postLookup: posts.getPost,
        latency: Duration.zero,
      );
      await expectLater(
        anon.createComment(postId: 'p2', body: 'x'),
        throwsA(_code('forbidden')),
      );
    });
  });

  group('editComment', () {
    test('pemilik bisa mengubah dalam 5 menit', () async {
      final c = await repo.createComment(postId: 'p2', body: 'lama');
      final e = await repo.editComment(c.id, 'baru');
      expect(e.body, 'baru');
      expect(e.isEdited, isTrue);
    });

    test('komentar orang lain tidak bisa diubah', () async {
      final list = await repo.fetchComments('p2');
      final other = list.firstWhere((c) => !c.isMine && !c.isDeleted);
      await expectLater(
        repo.editComment(other.id, 'x'),
        throwsA(_code('forbidden')),
      );
    });

    test('isi tidak valid ditolak', () async {
      final c = await repo.createComment(postId: 'p2', body: 'lama');
      await expectLater(
        repo.editComment(c.id, ' '),
        throwsA(_code('invalid_body')),
      );
    });
  });

  group('deleteComment', () {
    test('tanpa balasan -> hilang dan jumlah berkurang', () async {
      final c = await repo.createComment(postId: 'p2', body: 'hapus aku');
      deltas.clear();
      expect(await repo.deleteComment(c.id), isNull);
      expect(deltas, [-1]);
      final list = await repo.fetchComments('p2');
      expect(list.any((x) => x.id == c.id), isFalse);
    });

    test('punya balasan -> jadi [komentar dihapus]', () async {
      final root = await repo.createComment(postId: 'p2', body: 'induk');
      await repo.createComment(postId: 'p2', body: 'anak', parentId: root.id);
      deltas.clear();
      final r = await repo.deleteComment(root.id);
      expect(r, isNotNull);
      expect(r!.isDeleted, isTrue);
      expect(r.body, isNull);
      expect(deltas, isEmpty);
    });

    test('bukan milik sendiri -> forbidden', () async {
      final list = await repo.fetchComments('p2');
      final other = list.firstWhere((c) => !c.isMine && !c.isDeleted);
      await expectLater(
        repo.deleteComment(other.id),
        throwsA(_code('forbidden')),
      );
    });
  });

  group('Layar detail', () {
    Widget app() => ProviderScope(
      overrides: [
        postRepositoryProvider.overrideWithValue(posts),
        commentRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: PostDetailScreen(postId: 'p3')),
    );

    void bigScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('kirim komentar baru muncul dan jumlah bertambah', (
      tester,
    ) async {
      bigScreen(tester);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Komentar 9'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'komentar uji');
      await tester.pump();
      await tester.tap(find.byTooltip('Kirim komentar'));
      await tester.pumpAndSettle();

      expect(find.text('komentar uji'), findsOneWidget);
      expect(find.text('Komentar 10'), findsOneWidget);
    });

    testWidgets('tombol kirim nonaktif saat kosong', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final btn = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.send_rounded),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('Balas menampilkan chip mode balas dan bisa dibatalkan', (
      tester,
    ) async {
      bigScreen(tester);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Balas').first);
      await tester.pump();
      expect(find.textContaining('Membalas'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(find.textContaining('Membalas'), findsNothing);
    });

    testWidgets('postingan selesai -> input diganti "Komentar ditutup"', (
      tester,
    ) async {
      bigScreen(tester);
      await tester.runAsync(() => posts.closePost('p15'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            postRepositoryProvider.overrideWithValue(posts),
            commentRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: PostDetailScreen(postId: 'p15')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Komentar ditutup'), findsWidgets);
      expect(find.byType(TextField), findsNothing);
    });
  });
}
