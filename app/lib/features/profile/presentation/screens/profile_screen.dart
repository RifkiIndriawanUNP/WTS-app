import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/user_profile.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../moderation/domain/report.dart';
import '../../../moderation/presentation/widgets/report_sheet.dart';
import '../../../timeline/data/post_repository.dart';
import '../../../timeline/domain/post.dart';
import '../../../timeline/presentation/providers/feed_providers.dart';
import '../../../timeline/presentation/screens/post_detail_screen.dart';
import '../../../timeline/presentation/widgets/image_viewer.dart';
import '../../../timeline/presentation/widgets/post_actions.dart';
import '../../../timeline/presentation/widgets/post_card.dart';
import '../../../timeline/presentation/widgets/post_card_skeleton.dart';
import '../../../timeline/presentation/widgets/post_share.dart';
import '../../data/profile_repository.dart';
import '../../domain/public_profile.dart';
import '../profile_navigation.dart';
import '../providers/profile_providers.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_tab_bar.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

class _TabData {
  _TabData({this.loading = false});

  final List<Post> items = [];
  bool loading;
  bool hasMore = true;
  bool loaded = false;
  String? error;
  int generation = 0;
}

/// Layar Profil. Tanpa [username] = profil sendiri (isi tab Profil, ada tab
/// Saved dan aksi ubah). Dengan [username] = profil orang lain ([showBack]
/// bila dibuka sebagai layar sendiri).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.username, this.showBack = false});

  final String? username;
  final bool showBack;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ScrollController _scroll = ScrollController();
  final Map<ProfileTab, _TabData> _data = {
    ProfileTab.posts: _TabData(loading: true),
    ProfileTab.saved: _TabData(),
  };
  ProfileTab _tab = ProfileTab.posts;

  UserProfile? get _me => ref.read(authControllerProvider).user;
  String? get _username => widget.username ?? _me?.username;
  bool get _isOwn =>
      widget.username == null || widget.username == _me?.username;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _fetch(ProfileTab.posts, reset: true, rebuild: false);
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
      _fetch(_tab);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<FeedPage> _page(ProfileTab tab, int offset) {
    final repo = ref.read(postRepositoryProvider);
    if (tab == ProfileTab.saved) {
      return repo.fetchSaved(offset: offset);
    }
    return repo.fetchByAuthor(username: _username ?? '', offset: offset);
  }

  /// Muat halaman berikutnya ([reset] = dari awal). Halaman lanjutan hanya
  /// dimuat setelah halaman pertama berhasil.
  Future<void> _fetch(
    ProfileTab tab, {
    bool reset = false,
    bool rebuild = true,
  }) async {
    final data = _data[tab];
    if (data == null) {
      return;
    }
    if (!reset && (data.loading || !data.hasMore || !data.loaded)) {
      return;
    }
    final gen = ++data.generation;
    data.loading = true;
    data.error = null;
    if (rebuild) {
      setState(() {});
    }
    try {
      final page = await _page(tab, reset ? 0 : data.items.length);
      if (!mounted || gen != data.generation) {
        return;
      }
      setState(() {
        if (reset) {
          data.items.clear();
        }
        data.items.addAll(page.items);
        data.hasMore = page.hasMore;
        data.loaded = true;
        data.loading = false;
      });
    } on PostException catch (e) {
      if (mounted && gen == data.generation) {
        setState(() {
          data.error = e.message;
          data.loading = false;
        });
      }
    }
  }

  void _selectTab(ProfileTab tab) {
    if (tab == _tab) {
      return;
    }
    setState(() => _tab = tab);
    final data = _data[tab];
    if (data != null && !data.loaded && !data.loading) {
      _fetch(tab, reset: true);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(publicProfileProvider);
    await _fetch(_tab, reset: true);
  }

  // ----- aksi pada kartu -----

  void _replace(Post updated) {
    setState(() {
      for (final entry in _data.entries) {
        final list = entry.value.items;
        final i = list.indexWhere((p) => p.id == updated.id);
        if (entry.key == ProfileTab.saved) {
          if (i >= 0 && !updated.isSaved) {
            list.removeAt(i);
          } else if (i >= 0) {
            list[i] = updated;
          } else if (updated.isSaved) {
            entry.value.loaded = false; // muat ulang saat tab dibuka
          }
        } else if (i >= 0) {
          list[i] = updated;
        }
      }
    });
  }

  void _remove(String postId) {
    setState(() {
      for (final data in _data.values) {
        data.items.removeWhere((p) => p.id == postId);
      }
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
        _remove(post.id);
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
        _remove(post.id);
      }
    }
  }

  // ----- aksi profil sendiri -----

  Future<void> _editInfo() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
    if (saved == true && mounted) {
      _snack('Profil diperbarui');
      _afterProfileChanged();
    }
  }

  /// Nama/foto penulis tampil di setiap kartu; muat ulang daftar yang tersimpan.
  void _afterProfileChanged() {
    ref.read(feedControllerProvider.notifier).refresh();
    for (final entry in _data.entries) {
      entry.value.loaded = entry.key == _tab ? entry.value.loaded : false;
    }
    _fetch(_tab, reset: true);
  }

  Future<void> _setPhoto() async {
    final me = _me;
    if (me == null) {
      return;
    }
    final pick = await pickAvatar(context, canRemove: me.avatarPath != null);
    if (pick == null || !mounted) {
      return;
    }
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            username: me.username,
            prodiId: me.prodiId,
            bio: me.bio,
            avatarPath: pick.path,
          );
      if (mounted) {
        _snack(
          pick.path == null ? 'Foto profil dihapus' : 'Foto profil diperbarui',
        );
        _afterProfileChanged();
      }
    } on AuthException catch (e) {
      if (mounted) {
        _snack(e.message);
      }
    }
  }

  void _openSettings() {
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  Future<void> _reportUser() async {
    final sent = await showReportSheet(
      context,
      target: ReportTarget.user,
      targetId: _username ?? '',
    );
    if (sent && mounted) {
      showReportSentSnack(context);
    }
  }

  // ----- tampilan -----

  PublicProfile _ownProfile(UserProfile me) => PublicProfile(
    username: me.username,
    joinedAt: me.createdAt,
    prodiName: me.prodiName,
    bio: me.bio,
    avatarPath: me.avatarPath,
  );

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider.select((s) => s.user));
    final own = _isOwn;

    final Widget content;
    if (own) {
      content = me == null
          ? const Center(child: Text('Silakan masuk dulu'))
          : _list(_ownProfile(me), own: true);
    } else {
      final async = ref.watch(publicProfileProvider(widget.username!));
      content = async.when(
        data: (p) => _list(p, own: false),
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
        error: (e, _) => _Notice(
          icon: Icons.person_off_outlined,
          title: e is ProfileException && e.code == 'not_found'
              ? 'Pengguna tidak ditemukan'
              : 'Profil gagal dimuat',
          message: e is ProfileException ? e.message : 'Coba lagi nanti.',
          actionLabel: 'Coba lagi',
          onAction: () =>
              ref.invalidate(publicProfileProvider(widget.username!)),
        ),
      );
    }

    if (!widget.showBack) {
      return content;
    }
    return GlassScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Kembali',
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Spacer(),
                  if (!own)
                    IconButton(
                      onPressed: _reportUser,
                      tooltip: 'Laporkan pengguna',
                      icon: const Icon(Icons.flag_outlined),
                    ),
                ],
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _list(PublicProfile profile, {required bool own}) {
    final tabs = [
      ProfileTab.posts,
      ProfileTab.market,
      if (own) ProfileTab.saved,
    ];
    final data = _data[_tab];
    final theme = Theme.of(context);

    final body = <Widget>[];
    if (_tab == ProfileTab.market) {
      body.add(
        const _Notice(
          icon: Icons.storefront_outlined,
          title: 'Belum ada produk',
          message: 'Produk yang dijual akan tampil di sini setelah fitur Market tersedia.',
        ),
      );
    } else if (data != null) {
      if (data.error != null && data.items.isEmpty) {
        body.add(
          _Notice(
            icon: Icons.cloud_off_rounded,
            title: 'Gagal memuat',
            message: data.error!,
            actionLabel: 'Coba lagi',
            onAction: () => _fetch(_tab, reset: true),
          ),
        );
      } else if (data.loading && data.items.isEmpty) {
        body.add(const PostCardSkeleton());
      } else if (data.items.isEmpty) {
        final saved = _tab == ProfileTab.saved;
        body.add(
          _Notice(
            icon: saved ? Icons.bookmark_border_rounded : Icons.forum_outlined,
            title: saved ? 'Belum ada yang disimpan' : 'Belum ada postingan',
            message: saved
                ? 'Ketuk ikon simpan pada postingan untuk menyimpannya di sini.'
                : (own
                      ? 'Postinganmu akan tampil di sini.'
                      : '@${profile.username} belum memposting apa pun.'),
          ),
        );
      } else {
        for (final post in data.items) {
          body.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PostCard(
                post: post,
                onOpen: () => _open(post),
                onVote: (d) => _vote(post, d),
                onSave: () => _save(post),
                onShare: () => sharePost(context, post),
                onMenu: () => _menu(post),
                onImageTap: (i) => showImageViewer(
                  context,
                  images: post.images,
                  initialIndex: i,
                ),
                onAuthorTap:
                    post.authorUsername == null ||
                        post.authorUsername == _username
                    ? null
                    : () => openUserProfile(context, post.authorUsername!),
              ),
            ),
          );
        }
        if (data.loading) {
          body.add(
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            ),
          );
        } else if (data.error != null) {
          body.add(
            Center(
              child: TextButton(
                onPressed: () => _fetch(_tab),
                child: const Text('Gagal memuat lagi. Coba lagi'),
              ),
            ),
          );
        }
      }
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 4, 16, widget.showBack ? 24 : 110),
        children: [
          ProfileHeader(
            profile: profile,
            isOwn: own,
            onSetPhoto: _setPhoto,
            onEditInfo: _editInfo,
            onSettings: _openSettings,
          ),
          const SizedBox(height: 4),
          ProfileTabBar(tabs: tabs, current: _tab, onChanged: _selectTab),
          Divider(
            height: 24,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          ...body,
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
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
    );
  }
}
