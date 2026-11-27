import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/profile_navigation.dart';
import '../../data/post_repository.dart';
import '../../domain/post.dart';
import '../providers/feed_providers.dart';
import 'post_detail_screen.dart';
import 'post_form_screen.dart';
import 'post_search_screen.dart';
import '../widgets/feed_states.dart';
import '../widgets/image_viewer.dart';
import '../widgets/post_card.dart';
import '../widgets/post_actions.dart';
import '../widgets/post_card_skeleton.dart';
import '../widgets/post_filter_sheet.dart';
import '../widgets/post_share.dart';

/// Tab Home: linimasa komunitas. Dipasang A sebagai tab pertama.
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({
    super.key,
    this.onCompose,
    this.onOpenPost,
    this.onOpenProfile,
  });

  /// Tombol "+". Kosong = membuka PostFormScreen lewat Navigator; A dapat
  /// menggantinya dengan `context.push(TimelineRoutes.compose)`.
  final VoidCallback? onCompose;

  /// Buka detail postingan. Kosong = membuka PostDetailScreen lewat Navigator;
  /// A dapat menggantinya dengan `context.push(TimelineRoutes.detailPath(id))`.
  final ValueChanged<Post>? onOpenPost;

  /// Ketuk avatar di pojok kanan atas (pindah ke tab Profil).
  final VoidCallback? onOpenProfile;

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

/// Jarak FAB dari dasar layar (di atas bilah navigasi kaca ±76dp).
const double _fabBottom = 84;

class _HomeTabState extends ConsumerState<HomeTab> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) {
      return;
    }
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
      ref.read(feedControllerProvider.notifier).loadMore();
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _vote(Post post, int direction) async {
    try {
      await ref
          .read(feedControllerProvider.notifier)
          .toggleVote(post, direction);
    } on PostException catch (e) {
      if (mounted) {
        _snack(e.message);
      }
    }
  }

  Future<void> _save(Post post) async {
    try {
      await ref.read(feedControllerProvider.notifier).toggleSave(post);
    } on PostException catch (e) {
      if (mounted) {
        _snack(e.message);
      }
    }
  }

  Future<void> _menu(Post post) => showPostActions(context, ref, post);

  Future<void> _compose() async {
    final custom = widget.onCompose;
    if (custom != null) {
      custom();
      return;
    }
    final created = await Navigator.of(context)
        .push<Post>(MaterialPageRoute(builder: (_) => const PostFormScreen()));
    if (created != null && mounted) {
      _snack('Postingan terbit');
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _pickSort() async {
    final current = ref.read(feedControllerProvider).sort;
    final picked = await showOptionPicker(
      context,
      title: 'Urutkan linimasa',
      options: [for (final s in PostSort.values) s.label],
      selected: current.label,
    );
    if (picked == null || !mounted) {
      return;
    }
    final sort = PostSort.values.firstWhere((s) => s.label == picked);
    await ref.read(feedControllerProvider.notifier).setSort(sort);
  }

  Future<void> _openFilter() async {
    final controller = ref.read(feedControllerProvider.notifier);
    final result = await showPostFilterSheet(
      context,
      ref.read(feedControllerProvider).filter,
    );
    if (result != null && mounted) {
      await controller.setFilter(result);
    }
  }

  void _openSearch() {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const PostSearchScreen()));
  }

  void _open(Post post) {
    final cb = widget.onOpenPost;
    if (cb != null) {
      cb(post);
    } else {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(postId: post.id, initial: post),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedControllerProvider);
    final controller = ref.read(feedControllerProvider.notifier);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final List<Widget> body;
    switch (feed.status) {
      case FeedStatus.loading:
        body = [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.separated(
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, _) => const PostCardSkeleton(),
            ),
          ),
        ];
      case FeedStatus.error:
        body = [
          SliverToBoxAdapter(
            child: FeedError(
              message: feed.errorMessage ?? 'Terjadi kesalahan.',
              onRetry: controller.refresh,
            ),
          ),
        ];
      case FeedStatus.ready:
        if (feed.items.isEmpty) {
          body = [
            SliverToBoxAdapter(
              child: FeedEmpty(
                filtered: feed.tagId != null || feed.filter.isActive,
                onReset: controller.resetFilters,
              ),
            ),
          ];
        } else {
          body = [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: feed.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final post = feed.items[i];
                  return PostCard(
                    key: ValueKey(post.id),
                    post: post,
                    onOpen: () => _open(post),
                    onAuthorTap: post.authorUsername == null
                        ? null
                        : () => openUserProfile(context, post.authorUsername!),
                    onVote: (dir) => _vote(post, dir),
                    onSave: () => _save(post),
                    onShare: () => sharePost(context, post),
                    onMenu: () => _menu(post),
                    onImageTap: (i) => showImageViewer(
                      context,
                      images: post.images,
                      initialIndex: i,
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: _Footer(feed: feed, onRetry: controller.loadMore),
            ),
          ];
        }
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: controller.refresh,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _Header(onOpenProfile: widget.onOpenProfile),
              ),
              SliverToBoxAdapter(
                child: _SearchRow(
                  onSearch: _openSearch,
                  onFilter: _openFilter,
                  activeFilters: feed.filter.activeCount,
                ),
              ),
              const SliverToBoxAdapter(child: _TagRow()),
              SliverToBoxAdapter(child: _SortRow(onTap: _pickSort)),
              ...body,
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
        Positioned(
          right: 20,
          bottom: bottomInset + _fabBottom,
          child: FloatingActionButton(
            heroTag: 'compose_post',
            tooltip: 'Buat postingan',
            shape: const CircleBorder(),
            onPressed: _compose,
            child: const Icon(Icons.add_rounded, size: 28),
          ),
        ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({this.onOpenProfile});

  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider.select((s) => s.user));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Image.asset('assets/images/logo_wts.png', width: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Want to Share',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          GestureDetector(
            onTap: onOpenProfile,
            child: UserAvatar(
              initials: user?.initials ?? '?',
              imagePath: user?.avatarPath,
              size: 40,
              glass: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.onSearch,
    required this.onFilter,
    this.activeFilters = 0,
  });

  final VoidCallback onSearch;
  final VoidCallback onFilter;

  /// Jumlah filter aktif; tampil sebagai angka kecil pada tombol Filter.
  final int activeFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: GlassContainer(
              radius: 100,
              blur: 14,
              shadow: false,
              child: InkWell(
                borderRadius: BorderRadius.circular(100),
                onTap: onSearch,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Cari kisi-kisi, kuesioner, info kampus',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Stack(
            clipBehavior: Clip.none,
            children: [
              GlassIconButton(
                icon: Icons.tune_rounded,
                tooltip: 'Filter',
                onPressed: onFilter,
              ),
              if (activeFilters > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: IgnorePointer(
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.brandBlue,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$activeFilters',
                        key: const ValueKey('filter_badge'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TagRow extends ConsumerWidget {
  const _TagRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags =
        ref.watch(timelineTagsProvider).asData?.value ?? const <PostTag>[];
    final selected = ref.watch(feedControllerProvider.select((s) => s.tagId));
    final controller = ref.read(feedControllerProvider.notifier);

    return SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          GlassChip(
            label: 'Semua',
            selected: selected == null,
            onTap: () => controller.selectTag(null),
          ),
          for (final t in tags) ...[
            const SizedBox(width: 8),
            GlassChip(
              label: t.name,
              selected: selected == t.id,
              onTap: () => controller.selectTag(t.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.feed, required this.onRetry});

  final FeedState feed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget child;
    if (feed.loadingMore) {
      child = const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      );
    } else if (feed.loadMoreFailed) {
      child = TextButton(
        onPressed: onRetry,
        child: const Text('Gagal memuat. Coba lagi'),
      );
    } else if (!feed.hasMore) {
      child = Text(
        'Kamu sudah sampai ujung',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    } else {
      child = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(child: child),
    );
  }
}

class _SortRow extends ConsumerWidget {
  const _SortRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sort = ref.watch(feedControllerProvider.select((s) => s.sort));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      child: Row(
        children: [
          Text(
            'Urutkan',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.swap_vert_rounded, size: 18),
            label: Text(sort.label),
          ),
        ],
      ),
    );
  }
}
