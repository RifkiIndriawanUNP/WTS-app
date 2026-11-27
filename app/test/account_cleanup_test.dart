import 'package:flutter_test/flutter_test.dart';
import 'package:wts/features/auth/domain/user_profile.dart';
import 'package:wts/features/comments/data/fake_comment_repository.dart';
import 'package:wts/features/timeline/data/fake_post_repository.dart';
import 'package:wts/features/timeline/domain/post.dart';

final _me = UserProfile(
  id: 'u1',
  email: 'saya@nusaputra.ac.id',
  username: 'saya_mhs',
  createdAt: DateTime(2026, 9, 1),
);

void main() {
  test('data pengguna hilang setelah akun dihapus (repo palsu)', () async {
    final posts = FakePostRepository(
      currentUser: () => _me,
      latency: Duration.zero,
    );
    await posts.toggleSave('p4');
    await posts.setVote('p3', 1);
    expect((await posts.fetchByAuthor(username: 'saya_mhs')).items, isNotEmpty);

    posts.purgeCurrentUserData();

    expect((await posts.fetchByAuthor(username: 'saya_mhs')).items, isEmpty);
    expect((await posts.fetchSaved()).items, isEmpty);
    final feed = await posts.fetchFeed(sort: PostSort.newest, limit: 50);
    expect(feed.items.any((p) => p.isMine), isFalse);
    expect(feed.items.every((p) => p.myVote == 0), isTrue);
    expect(
      feed.items.any((p) => p.id == 'p3'),
      isTrue,
    ); // postingan orang lain tetap
  });

  test(
    'komentar milik sendiri dibersihkan dan jumlah komentar menyesuaikan',
    () async {
      final posts = FakePostRepository(
        currentUser: () => _me,
        latency: Duration.zero,
      );
      final comments = FakeCommentRepository(
        postLookup: posts.getPost,
        currentUser: () => _me,
        onCountChanged: posts.applyCommentDelta,
        latency: Duration.zero,
      );
      final before = (await posts.getPost('p2')).commentCount;
      final c = await comments.createComment(
        postId: 'p2',
        body: 'komentar saya',
      );
      expect((await posts.getPost('p2')).commentCount, before + 1);

      comments.purgeOwnComments();

      expect((await posts.getPost('p2')).commentCount, before);
      final list = await comments.fetchComments('p2');
      expect(list.any((x) => x.id == c.id), isFalse);
    },
  );
}
