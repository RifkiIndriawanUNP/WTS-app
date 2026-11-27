import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/fake_post_repository.dart';
import '../../data/post_repository.dart';
import '../../domain/post.dart';
import '../../domain/post_filter.dart';

/// Ganti isi provider ini dengan implementasi Supabase saat backend siap.
/// Preview/tes memakai `postRepositoryProvider.overrideWithValue(...)`.
final postRepositoryProvider = Provider<PostRepository>(
  (ref) => FakePostRepository(
    currentUser: () => ref.read(authControllerProvider).user,
  ),
);

final timelineTagsProvider = FutureProvider<List<PostTag>>(
  (ref) => ref.read(postRepositoryProvider).fetchTags(),
);

enum FeedStatus { loading, ready, error }

class FeedState {
  const FeedState({
    this.status = FeedStatus.loading,
    this.items = const [],
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreFailed = false,
    this.errorMessage,
    this.tagId,
    this.sort = PostSort.newest,
    this.filter = const PostFilter(),
  });

  final FeedStatus status;
  final List<Post> items;
  final bool hasMore;
  final bool loadingMore;

  /// Gagal memuat halaman berikutnya (tampilkan tombol "Coba lagi" di dasar daftar).
  final bool loadMoreFailed;
  final String? errorMessage;

  /// Null = semua tag.
  final int? tagId;
  final PostSort sort;
  final PostFilter filter;

  FeedState copyWith({
    FeedStatus? status,
    List<Post>? items,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
    String? errorMessage,
    int? tagId,
    bool clearTag = false,
    PostSort? sort,
    PostFilter? filter,
  }) {
    return FeedState(
      status: status ?? this.status,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      errorMessage: errorMessage,
      tagId: clearTag ? null : (tagId ?? this.tagId),
      sort: sort ?? this.sort,
      filter: filter ?? this.filter,
    );
  }
}

class FeedController extends Notifier<FeedState> {
  static const int _pageSize = 10;

  /// Menolak balasan lama bila pengguna sudah mengganti filter/urutan.
  int _generation = 0;

  PostRepository get _repo => ref.read(postRepositoryProvider);

  @override
  FeedState build() {
    Future<void>.microtask(_loadFirstPage);
    return const FeedState();
  }

  Future<void> _loadFirstPage() async {
    final gen = ++_generation;
    try {
      final page = await _repo.fetchFeed(
        sort: state.sort,
        tagId: state.tagId,
        filter: state.filter,
        limit: _pageSize,
      );
      if (!ref.mounted || gen != _generation) {
        return;
      }
      state = state.copyWith(
        status: FeedStatus.ready,
        items: page.items,
        hasMore: page.hasMore,
        loadingMore: false,
        loadMoreFailed: false,
      );
    } on PostException catch (e) {
      if (!ref.mounted || gen != _generation) {
        return;
      }
      state = state.copyWith(status: FeedStatus.error, errorMessage: e.message);
    }
  }

  /// Muat ulang dari awal (tarik untuk menyegarkan / tombol coba lagi).
  Future<void> refresh() async {
    final keep = state.status == FeedStatus.ready;
    if (!keep) {
      state = state.copyWith(status: FeedStatus.loading);
    }
    await _loadFirstPage();
  }

  Future<void> loadMore() async {
    if (state.status != FeedStatus.ready ||
        !state.hasMore ||
        state.loadingMore) {
      return;
    }
    final gen = _generation;
    state = state.copyWith(loadingMore: true, loadMoreFailed: false);
    try {
      final page = await _repo.fetchFeed(
        sort: state.sort,
        tagId: state.tagId,
        filter: state.filter,
        offset: state.items.length,
        limit: _pageSize,
      );
      if (!ref.mounted || gen != _generation) {
        return;
      }
      state = state.copyWith(
        items: [...state.items, ...page.items],
        hasMore: page.hasMore,
        loadingMore: false,
      );
    } on PostException {
      if (!ref.mounted || gen != _generation) {
        return;
      }
      state = state.copyWith(loadingMore: false, loadMoreFailed: true);
    }
  }

  Future<void> selectTag(int? tagId) async {
    if (tagId == state.tagId) {
      return;
    }
    state = state.copyWith(
      tagId: tagId,
      clearTag: tagId == null,
      status: FeedStatus.loading,
    );
    await _loadFirstPage();
  }

  /// Terapkan filter tambahan (rentang waktu, bergambar, sembunyikan selesai).
  Future<void> setFilter(PostFilter filter) async {
    if (filter == state.filter) {
      return;
    }
    state = state.copyWith(filter: filter, status: FeedStatus.loading);
    await _loadFirstPage();
  }

  /// Hapus tag dan filter sekaligus ("Lihat semua").
  Future<void> resetFilters() async {
    if (state.tagId == null && !state.filter.isActive) {
      return;
    }
    state = state.copyWith(
      clearTag: true,
      filter: const PostFilter(),
      status: FeedStatus.loading,
    );
    await _loadFirstPage();
  }

  Future<void> setSort(PostSort sort) async {
    if (sort == state.sort) {
      return;
    }
    state = state.copyWith(sort: sort, status: FeedStatus.loading);
    await _loadFirstPage();
  }

  void _replace(Post updated) {
    state = state.copyWith(
      items: [for (final p in state.items) p.id == updated.id ? updated : p],
    );
  }

  /// Tekan upvote/downvote: tekan lagi di tombol yang sama = batalkan.
  /// Tampilan langsung berubah (optimistic) dan dikembalikan bila gagal;
  /// melempar [PostException] agar UI bisa menampilkan pesan.
  Future<Post> toggleVote(Post post, int direction) async {
    final current = state.items.firstWhere(
      (p) => p.id == post.id,
      orElse: () => post,
    );
    if (current.isMine) {
      throw const PostException(
        'Kamu tidak bisa memberi suara pada postinganmu sendiri',
        code: 'own_content',
      );
    }
    final next = current.myVote == direction ? 0 : direction;
    _replace(current.withVote(next));
    try {
      final server = await _repo.setVote(post.id, next);
      if (ref.mounted) {
        _replace(server);
      }
      return server;
    } on PostException {
      if (ref.mounted) {
        _replace(current);
      }
      rethrow;
    }
  }

  Future<Post> toggleSave(Post post) async {
    final current = state.items.firstWhere(
      (p) => p.id == post.id,
      orElse: () => post,
    );
    _replace(current.copyWith(isSaved: !current.isSaved));
    try {
      final saved = await _repo.toggleSave(post.id);
      final result = current.copyWith(isSaved: saved);
      if (ref.mounted) {
        _replace(result);
      }
      return result;
    } on PostException {
      if (ref.mounted) {
        _replace(current);
      }
      rethrow;
    }
  }

  /// Samakan jumlah komentar di daftar Home setelah komentar dibuat/dihapus
  /// dari layar detail.
  void patchCommentCount(String postId, int delta) {
    state = state.copyWith(
      items: [
        for (final p in state.items)
          if (p.id == postId)
            p.copyWith(commentCount: (p.commentCount + delta).clamp(0, 1 << 30))
          else
            p,
      ],
    );
  }

  /// Hapus postingan milik sendiri; hilang dari daftar. Melempar [PostException].
  Future<void> deletePost(Post post) async {
    await _repo.deletePost(post.id);
    if (ref.mounted) {
      state = state.copyWith(
        items: [
          for (final p in state.items)
            if (p.id != post.id) p,
        ],
      );
    }
  }

  /// Tandai selesai. Melempar [PostException].
  Future<Post> closePost(Post post) async {
    final updated = await _repo.closePost(post.id);
    if (ref.mounted) {
      _replace(updated);
    }
    return updated;
  }

  /// Buat postingan lalu muat ulang feed agar muncul di atas. Melempar [PostException].
  Future<Post> createPost(PostDraft draft) async {
    final created = await _repo.createPost(draft);
    if (ref.mounted) {
      await refresh();
    }
    return created;
  }

  /// Ubah caption (24 jam pertama). Melempar [PostException].
  Future<Post> updateCaption(Post post, String caption) async {
    final updated = await _repo.updateCaption(post.id, caption);
    if (ref.mounted) {
      _replace(updated);
    }
    return updated;
  }
}

final feedControllerProvider = NotifierProvider<FeedController, FeedState>(
  FeedController.new,
);
