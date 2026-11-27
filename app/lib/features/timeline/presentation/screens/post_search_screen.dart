import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../../profile/presentation/profile_navigation.dart';
import '../../data/post_repository.dart';
import '../../data/search_history_store.dart';
import '../../domain/post.dart';
import '../providers/feed_providers.dart';
import '../widgets/image_viewer.dart';
import '../widgets/post_actions.dart';
import '../widgets/post_card.dart';
import '../widgets/post_card_skeleton.dart';
import '../widgets/post_share.dart';
import 'post_detail_screen.dart';

enum _SearchStatus { idle, tooShort, loading, ready, error }

/// Pencarian postingan linimasa: isi postingan dan nama tag. Riwayat tersimpan
/// di perangkat; tag tampil sebagai pintasan saat kolom kosong.
class PostSearchScreen extends ConsumerStatefulWidget {
  const PostSearchScreen({
    super.key,
    this.initialQuery,
    this.history = const SearchHistoryStore(),
  });

  final String? initialQuery;
  final SearchHistoryStore history;

  @override
  ConsumerState<PostSearchScreen> createState() => _PostSearchScreenState();
}

class _PostSearchScreenState extends ConsumerState<PostSearchScreen> {
  static const int _pageSize = 10;
  static const int _minChars = 2;

  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;

  _SearchStatus _status = _SearchStatus.idle;
  String _query = '';
  PostSort _sort = PostSort.newest;
  List<Post> _items = [];
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;
  String? _error;
  int _generation = 0;
  List<String> _history = const [];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    widget.history.load().then((h) {
      if (mounted) {
        setState(() => _history = h);
      }
    });
    final initial = widget.initialQuery;
    if (initial != null && initial.trim().isNotEmpty) {
      _input.text = initial;
      _query = initial.trim();
      _status = _SearchStatus.loading;
      _run(_query);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
      _loadMore();
    }
  }

  // ----- pencarian -----

  void _onChanged(String raw) {
    _debounce?.cancel();
    final q = raw.trim();
    if (q.isEmpty) {
      _generation++;
      setState(() {
        _status = _SearchStatus.idle;
        _query = '';
        _items = [];
      });
      return;
    }
    if (q.length < _minChars) {
      _generation++;
      setState(() {
        _status = _SearchStatus.tooShort;
        _query = q;
        _items = [];
      });
      return;
    }
    setState(() {
      _status = _SearchStatus.loading;
      _query = q;
    });
    _debounce = Timer(const Duration(milliseconds: 400), () => _run(q));
  }

  /// Cari sekarang (tombol cari di keyboard, riwayat, atau pintasan tag).
  void _submit(String raw) {
    _debounce?.cancel();
    final q = raw.trim();
    if (q.length < _minChars) {
      _onChanged(raw);
      return;
    }
    _focus.unfocus();
    setState(() {
      _status = _SearchStatus.loading;
      _query = q;
    });
    _run(q);
    widget.history.add(q).then((h) {
      if (mounted) {
        setState(() => _history = h);
      }
    });
  }

  void _useText(String text) {
    _input.text = text;
    _input.selection = TextSelection.collapsed(offset: text.length);
    _submit(text);
  }

  Future<void> _run(String q) async {
    final gen = ++_generation;
    try {
      final page = await ref
          .read(postRepositoryProvider)
          .fetchFeed(sort: _sort, query: q, limit: _pageSize);
      if (!mounted || gen != _generation) {
        return;
      }
      setState(() {
        _items = page.items;
        _hasMore = page.hasMore;
        _loadingMore = false;
        _loadMoreFailed = false;
        _error = null;
        _status = _SearchStatus.ready;
      });
    } on PostException catch (e) {
      if (mounted && gen == _generation) {
        setState(() {
          _error = e.message;
          _status = _SearchStatus.error;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_status != _SearchStatus.ready || !_hasMore || _loadingMore) {
      return;
    }
    final gen = _generation;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    try {
      final page = await ref
          .read(postRepositoryProvider)
          .fetchFeed(
            sort: _sort,
            query: _query,
            offset: _items.length,
            limit: _pageSize,
          );
      if (!mounted || gen != _generation) {
        return;
      }
      setState(() {
        _items = [..._items, ...page.items];
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } on PostException {
      if (mounted && gen == _generation) {
        setState(() {
          _loadingMore = false;
          _loadMoreFailed = true;
        });
      }
    }
  }

  Future<void> _pickSort() async {
    final picked = await showOptionPicker(
      context,
      title: 'Urutkan hasil',
      options: [for (final s in PostSort.values) s.label],
      selected: _sort.label,
    );
    if (picked == null || !mounted) {
      return;
    }
    final sort = PostSort.values.firstWhere((s) => s.label == picked);
    if (sort == _sort) {
      return;
    }
    setState(() {
      _sort = sort;
      _status = _SearchStatus.loading;
    });
    await _run(_query);
  }

  // ----- aksi kartu -----

  void _replace(Post updated) {
    setState(() {
      _items = [for (final p in _items) p.id == updated.id ? updated : p];
    });
  }

  Future<void> _vote(Post post, int direction) async {
    try {
      final updated = await ref
          .read(feedControllerProvider.notifier)
          .toggleVote(post, direction);
      if (mounted) {
        _replace(updated);
      }
    } on PostException catch (e) {
      if (mounted) {
        _snack(e.message);
      }
    }
  }

  Future<void> _save(Post post) async {
    try {
      final updated = await ref
          .read(feedControllerProvider.notifier)
          .toggleSave(post);
      if (mounted) {
        _replace(updated);
      }
    } on PostException catch (e) {
      if (mounted) {
        _snack(e.message);
      }
    }
  }

  Future<void> _menu(Post post) async {
    final result = await showPostActions(context, ref, post);
    if (!mounted) {
      return;
    }
    switch (result.outcome) {
      case PostActionOutcome.deleted:
        setState(
          () => _items = [
            for (final p in _items)
              if (p.id != post.id) p,
          ],
        );
      case PostActionOutcome.edited:
      case PostActionOutcome.closed:
        if (result.post != null) {
          _replace(result.post!);
        }
      case PostActionOutcome.reported:
      case PostActionOutcome.none:
        break;
    }
  }

  Future<void> _open(Post post) async {
    widget.history.add(_query).then((h) {
      if (mounted) {
        setState(() => _history = h);
      }
    });
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: post.id, initial: post),
      ),
    );
    if (!mounted) {
      return;
    }
    try {
      final fresh = await ref.read(postRepositoryProvider).getPost(post.id);
      if (mounted) {
        _replace(fresh);
      }
    } on PostException catch (e) {
      if (mounted && e.code == 'not_found') {
        setState(
          () => _items = [
            for (final p in _items)
              if (p.id != post.id) p,
          ],
        );
      }
    }
  }

  // ----- tampilan -----

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Kembali',
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: GlassContainer(
                      radius: 100,
                      blur: 14,
                      shadow: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _input,
                                focusNode: _focus,
                                autofocus: widget.initialQuery == null,
                                textInputAction: TextInputAction.search,
                                onChanged: _onChanged,
                                onSubmitted: _submit,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Cari kisi-kisi, kuesioner, info kampus',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                ),
                              ),
                            ),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _input,
                              builder: (context, value, _) => value.text.isEmpty
                                  ? const SizedBox.shrink()
                                  : InkResponse(
                                      onTap: () {
                                        _input.clear();
                                        _onChanged('');
                                        _focus.requestFocus();
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _content(theme)),
          ],
        ),
      ),
    );
  }

  Widget _content(ThemeData theme) {
    switch (_status) {
      case _SearchStatus.idle:
        return _idle(theme);
      case _SearchStatus.tooShort:
        return _Notice(
          icon: Icons.keyboard_rounded,
          title: 'Ketik minimal $_minChars huruf',
          message: 'Cari berdasarkan isi postingan atau nama tag.',
        );
      case _SearchStatus.loading:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: const [
            PostCardSkeleton(),
            SizedBox(height: 12),
            PostCardSkeleton(),
          ],
        );
      case _SearchStatus.error:
        return _Notice(
          icon: Icons.cloud_off_rounded,
          title: 'Pencarian gagal',
          message: _error ?? 'Terjadi kesalahan.',
          actionLabel: 'Coba lagi',
          onAction: () => _submit(_query),
        );
      case _SearchStatus.ready:
        if (_items.isEmpty) {
          return _Notice(
            icon: Icons.search_off_rounded,
            title: 'Tidak ada hasil untuk “$_query”',
            message: 'Coba kata kunci lain, atau cek ejaannya.',
          );
        }
        return ListView.separated(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: _items.length + 2,
          separatorBuilder: (context, i) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hasil untuk “$_query”',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickSort,
                    icon: const Icon(Icons.swap_vert_rounded, size: 18),
                    label: Text(_sort.label),
                  ),
                ],
              );
            }
            if (i == _items.length + 1) {
              if (_loadingMore) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                );
              }
              if (_loadMoreFailed) {
                return Center(
                  child: TextButton(
                    onPressed: _loadMore,
                    child: const Text('Gagal memuat lagi. Coba lagi'),
                  ),
                );
              }
              return const SizedBox.shrink();
            }
            final post = _items[i - 1];
            return PostCard(
              key: ValueKey(post.id),
              post: post,
              onOpen: () => _open(post),
              onVote: (d) => _vote(post, d),
              onSave: () => _save(post),
              onShare: () => sharePost(context, post),
              onMenu: () => _menu(post),
              onImageTap: (n) => showImageViewer(
                context,
                images: post.images,
                initialIndex: n,
              ),
              onAuthorTap: post.authorUsername == null
                  ? null
                  : () => openUserProfile(context, post.authorUsername!),
            );
          },
        );
    }
  }

  Widget _idle(ThemeData theme) {
    final tags =
        ref.watch(timelineTagsProvider).asData?.value ?? const <PostTag>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (_history.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pencarian terakhir',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await widget.history.clear();
                  if (mounted) {
                    setState(() => _history = const []);
                  }
                },
                child: const Text('Hapus semua'),
              ),
            ],
          ),
          for (final h in _history)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_rounded),
              title: Text(h),
              onTap: () => _useText(h),
              trailing: IconButton(
                tooltip: 'Hapus dari riwayat',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () async {
                  final next = await widget.history.remove(h);
                  if (mounted) {
                    setState(() => _history = next);
                  }
                },
              ),
            ),
          const SizedBox(height: 16),
        ],
        Text(
          'Cari berdasarkan kategori',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in tags)
              ActionChip(
                label: Text(t.name),
                onPressed: () => _useText(t.name),
              ),
          ],
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 200,
                child: GlassButton(label: actionLabel!, onPressed: onAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
