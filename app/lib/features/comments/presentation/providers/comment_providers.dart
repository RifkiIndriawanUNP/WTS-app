import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../timeline/presentation/providers/feed_providers.dart';
import '../../data/comment_repository.dart';
import '../../data/fake_comment_repository.dart';

/// Ganti isi provider ini dengan implementasi Supabase saat backend siap.
final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  final posts = ref.read(postRepositoryProvider);
  return FakeCommentRepository(
    // Jumlah & penulis postingan diambil dari repo postingan agar konsisten.
    postLookup: (id) => posts.getPost(id),
    currentUser: () => ref.read(authControllerProvider).user,
    onCountChanged: posts.applyCommentDelta,
  );
});
