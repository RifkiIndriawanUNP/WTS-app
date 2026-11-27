import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wts/features/comments/data/comment_repository.dart';
import 'package:wts/features/comments/data/fake_comment_repository.dart';
import 'package:wts/features/comments/domain/comment.dart';
import 'package:wts/features/comments/presentation/widgets/comment_tree.dart';
import 'package:wts/features/timeline/data/fake_post_repository.dart';
import 'package:wts/features/timeline/data/post_repository.dart';
import 'package:wts/features/timeline/presentation/providers/feed_providers.dart';
import 'package:wts/features/timeline/presentation/screens/post_detail_screen.dart';

Comment _c(
  String id, {
  String? parent,
  int depth = 0,
  int minutes = 0,
  int up = 0,
  int down = 0,
  String? body,
  CommentStatus status = CommentStatus.active,
}) => Comment(
  id: id,
  postId: 'p',
  parentId: parent,
  depth: depth,
  body: body ?? 'isi $id',
  status: status,
  authorUsername: 'user_$id',
  upvotes: up,
  downvotes: down,
  createdAt: DateTime(2026, 11, 14, 8, minutes),
);

class _TreeHost extends StatefulWidget {
  const _TreeHost({required this.nodes});

  final List<CommentNode> nodes;

  @override
  State<_TreeHost> createState() => _TreeHostState();
}

class _TreeHostState extends State<_TreeHost> {
  final Set<String> _open = {};

  @override
  Widget build(BuildContext context) {
    return CommentTree(
      nodes: widget.nodes,
      expanded: _open,
      onExpand: (id) => setState(() => _open.add(id)),
    );
  }
}

void main() {
  group('Comment', () {
    test('aturan isi komentar 1-1000', () {
      expect(CommentRules.validateBody(''), isNotNull);
      expect(CommentRules.validateBody('ok'), isNull);
      expect(CommentRules.validateBody('a' * 1000), isNull);
      expect(CommentRules.validateBody('a' * 1001), isNotNull);
    });

    test('balasan maksimal tiga tingkat', () {
      expect(_c('a').canReply, isTrue);
      expect(_c('b', depth: 1).canReply, isTrue);
      expect(_c('c', depth: 2).canReply, isFalse);
      expect(_c('d', status: CommentStatus.deleted).canReply, isFalse);
    });

    test('edit hanya 5 menit oleh pemilik', () {
      final now = DateTime.now();
      Comment mine(Duration age) => Comment(
        id: 'm',
        postId: 'p',
        createdAt: now.subtract(age),
        body: 'x',
        isMine: true,
      );
      expect(mine(const Duration(minutes: 2)).canEdit(now), isTrue);
      expect(mine(const Duration(minutes: 6)).canEdit(now), isFalse);
      expect(_c('o').canEdit(now), isFalse); // bukan milik sendiri
    });

    test('OP anonim ditampilkan sebagai Anonim', () {
      final c = Comment(
        id: 'a',
        postId: 'p',
        createdAt: DateTime(2026),
        body: 'x',
        isOp: true,
        isAnonymousOp: true,
      );
      expect(c.authorLabel, 'Anonim');
      expect(c.authorInitials, '?');
      expect(_c('z').authorLabel, '@user_z');
    });

    test('withVote menghitung ulang', () {
      var c = _c('v', up: 3, down: 1).withVote(1);
      expect((c.upvotes, c.downvotes, c.score), (4, 1, 3));
      c = c.withVote(-1);
      expect((c.upvotes, c.downvotes), (3, 2));
      c = c.withVote(0);
      expect((c.upvotes, c.downvotes, c.myVote), (3, 1, 0));
    });
  });

  group('buildCommentTree', () {
    final flat = [
      _c('r1', minutes: 1, up: 1),
      _c('r2', minutes: 5, up: 9),
      _c('a', parent: 'r1', depth: 1, minutes: 3),
      _c('b', parent: 'r1', depth: 1, minutes: 2),
      _c('a1', parent: 'a', depth: 2, minutes: 4),
      _c('orphan', parent: 'hilang', depth: 1, minutes: 6),
    ];

    test('susun pohon, balasan urut waktu, yatim dibuang', () {
      final roots = buildCommentTree(flat, CommentSort.oldest);
      expect(roots.map((n) => n.comment.id), ['r1', 'r2']);
      final r1 = roots.first;
      expect(r1.children.map((n) => n.comment.id), ['b', 'a']);
      expect(r1.children.last.children.single.comment.id, 'a1');
      expect(r1.descendantCount, 3);
    });

    test('urutan komentar utama', () {
      expect(
        buildCommentTree(flat, CommentSort.best).map((n) => n.comment.id),
        ['r2', 'r1'],
      );
      expect(
        buildCommentTree(flat, CommentSort.newest).map((n) => n.comment.id),
        ['r2', 'r1'],
      );
      expect(
        buildCommentTree(flat, CommentSort.oldest).map((n) => n.comment.id),
        ['r1', 'r2'],
      );
    });
  });

  group('FakeCommentRepository', () {
    late FakePostRepository posts;
    late FakeCommentRepository repo;
    setUp(() {
      posts = FakePostRepository(
        currentUser: () => null,
        latency: Duration.zero,
      );
      repo = FakeCommentRepository(
        postLookup: posts.getPost,
        latency: Duration.zero,
      );
    });

    test('jumlah komentar sama dengan jumlah di postingan', () async {
      final post = await posts.getPost('p2');
      final list = await repo.fetchComments('p2');
      expect(list.length, post.commentCount);
    });

    test('kedalaman maksimal 2, ada komentar dihapus dan penanda OP', () async {
      final list = await repo.fetchComments('p2');
      expect(list.every((c) => c.depth <= CommentRules.maxDepth), isTrue);
      expect(list.any((c) => c.depth == 2), isTrue);
      expect(list.any((c) => c.isDeleted && c.body == null), isTrue);
      expect(list.any((c) => c.isOp), isTrue);
      // p2 anonim: OP tidak membuka username
      expect(
        list
            .where((c) => c.isOp)
            .every((c) => c.isAnonymousOp && c.authorUsername == null),
        isTrue,
      );
    });

    test('semua balasan punya induk yang ada', () async {
      final list = await repo.fetchComments('p8');
      final ids = list.map((c) => c.id).toSet();
      expect(
        list
            .where((c) => c.parentId != null)
            .every((c) => ids.contains(c.parentId)),
        isTrue,
      );
    });

    test('vote berubah dan komentar tidak dikenal ditolak', () async {
      final list = await repo.fetchComments('p4');
      final voted = await repo.setVote(list.first.id, 1);
      expect(voted.myVote, 1);
      await expectLater(
        repo.setVote('tidak_ada', 1),
        throwsA(
          isA<CommentException>().having((e) => e.code, 'code', 'not_found'),
        ),
      );
    });

    test('error jaringan bisa disimulasikan', () async {
      repo.failNext = true;
      await expectLater(
        repo.fetchComments('p4'),
        throwsA(isA<CommentException>()),
      );
      expect(await repo.fetchComments('p4'), isNotEmpty);
    });
  });

  group('Tampilan', () {
    testWidgets('CommentTree melipat balasan dan membukanya', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final nodes = buildCommentTree([
        _c('r', minutes: 1, body: 'komentar utama'),
        _c('a', parent: 'r', depth: 1, minutes: 2, body: 'balasan pertama'),
        _c('b', parent: 'r', depth: 1, minutes: 3, body: 'balasan kedua'),
        _c('c', parent: 'r', depth: 1, minutes: 4, body: 'balasan ketiga'),
        _c('d', minutes: 5, body: 'dihapus', status: CommentStatus.deleted),
      ], CommentSort.oldest);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: _TreeHost(nodes: nodes)),
          ),
        ),
      );

      expect(find.text('balasan pertama'), findsOneWidget);
      expect(find.text('balasan kedua'), findsNothing);
      expect(find.text('Lihat 2 balasan lainnya'), findsOneWidget);
      expect(find.text('[komentar dihapus]'), findsOneWidget);

      await tester.tap(find.text('Lihat 2 balasan lainnya'));
      await tester.pump();
      expect(find.text('balasan kedua'), findsOneWidget);
      expect(find.text('balasan ketiga'), findsOneWidget);
      expect(find.text('Lihat 2 balasan lainnya'), findsNothing);
    });

    testWidgets('CommentTree memanggil onVote', (tester) async {
      Comment? voted;
      int? dir;
      final nodes = buildCommentTree([_c('r', body: 'halo')], CommentSort.best);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentTree(
              nodes: nodes,
              expanded: const {},
              onExpand: (_) {},
              onVote: (c, d) {
                voted = c;
                dir = d;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.arrow_downward_rounded));
      expect(voted?.id, 'r');
      expect(dir, -1);
    });

    testWidgets('PostDetailScreen memuat postingan dan komentar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
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
          child: const MaterialApp(home: PostDetailScreen(postId: 'p3')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Postingan'), findsOneWidget);
      expect(find.text('Mohon bantuan isi kuesioner skripsi'), findsOneWidget);
      expect(find.text('Komentar 9'), findsOneWidget);
      expect(find.text('Tambah komentar...'), findsOneWidget);
    });

    testWidgets('PostDetailScreen: postingan tidak ada menampilkan pesan', (
      tester,
    ) async {
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
          child: const MaterialApp(home: PostDetailScreen(postId: 'tidak_ada')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Postingan sudah tidak tersedia'), findsOneWidget);
      // Muat komentar (jeda 500 ms) masih berjalan; selesaikan sebelum tes berakhir.
      await tester.pump(const Duration(seconds: 1));
    });
  });

  test('getPost postingan hilang -> not_found', () async {
    final posts = FakePostRepository(
      currentUser: () => null,
      latency: Duration.zero,
    );
    await expectLater(
      posts.getPost('x'),
      throwsA(isA<PostException>().having((e) => e.code, 'code', 'not_found')),
    );
  });
}
