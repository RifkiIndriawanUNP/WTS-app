import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wts/core/router/nav_collapse.dart';
import 'package:wts/core/utils/guard.dart';
import 'package:wts/features/chat/domain/chat_models.dart';
import 'package:wts/features/chat/presentation/chat_list_providers.dart';
import 'package:wts/features/chat/presentation/chat_ui.dart';
import 'package:wts/features/chat/presentation/dm_providers.dart';
import 'package:wts/features/chat/presentation/market_chat_providers.dart';
import 'package:wts/shared/models/app_user.dart';
import 'package:wts/shared/widgets/common_widgets.dart';

enum _Filter { all, dm, market }

class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  _Filter _filter = _Filter.all;
  bool _searching = false;
  String _query = '';
  final _searchController = TextEditingController();
  final _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openSearch() => setState(() => _searching = true);

  void _closeSearch() {
    _searchController.clear();
    setState(() {
      _searching = false;
      _query = '';
    });
  }

  void _open(ChatListItem item) {
    context.push(
      item.kind == ChatKind.market
          ? '/chat/market/${item.id}'
          : '/chat/dm/${item.id}',
    );
  }

  Future<void> _newDm() async {
    final userId = await showChatSheet<String>(
      context,
      builder: (_) => const _ContactPickerSheet(),
    );
    if (userId == null || !mounted) return;
    final id = await guarded(
      context,
      () => ref.read(dmRepositoryProvider).startDm(userId),
    );
    if (id != null && mounted) context.push('/chat/dm/$id');
  }

  /// Geser daftar ke bawah -> navigasi bawah mengecil; geser balik -> muncul.
  bool _onScroll(UserScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final nav = ref.read(navCollapsedProvider.notifier);
    if (n.direction == ScrollDirection.reverse) {
      nav.set(true);
    } else if (n.direction == ScrollDirection.forward) {
      nav.set(false);
    }
    return false;
  }

  List<ChatListItem> _rows(List<ChatListItem> source, _Filter filter) {
    final q = _query.trim().toLowerCase();
    return source.where((i) {
      if (q.isNotEmpty &&
          !i.title.toLowerCase().contains(q) &&
          !i.subtitle.toLowerCase().contains(q)) {
        return false;
      }
      switch (filter) {
        case _Filter.all:
          return true;
        case _Filter.dm:
          return i.kind == ChatKind.dm;
        case _Filter.market:
          return i.kind == ChatKind.market;
      }
    }).toList();
  }

  Widget _buildPage(
    AsyncValue<List<ChatListItem>> async,
    _Filter filter,
    double bottom,
  ) {
    return async.when(
                        loading: () => ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                          itemCount: 6,
                          separatorBuilder: (context, i) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, i) =>
                              const SkeletonBox(height: 56, radius: 16),
                        ),
                        error: (e, _) => ErrorState(
                          onRetry: () {
                            ref.invalidate(dmConversationsProvider);
                            ref.invalidate(marketChatsProvider);
                          },
                        ),
                        data: (items) {
                          final rows = _rows(items, filter);
                          if (rows.isEmpty) {
                            return ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 60),
                                _query.trim().isNotEmpty
                                    ? const EmptyState(
                                        icon: Icons.search_off_rounded,
                                        title: 'Tidak ada hasil',
                                        message:
                                            'Coba kata kunci lain atau ubah filter.',
                                      )
                                    : const EmptyState(
                                        icon: Icons.chat_bubble_outline_rounded,
                                        title: 'Belum ada percakapan',
                                        message:
                                            'Mulai chat dari produk di Market atau tekan tombol pensil.',
                                      ),
                              ],
                            );
                          }
                          return ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.only(
                              top: 6,
                              bottom: 120 + bottom,
                            ),
                            itemCount: rows.length,
                            separatorBuilder: (context, i) => const Divider(
                              height: 1,
                              thickness: 1,
                              color: ChatColors.line,
                            ),
                            itemBuilder: (context, i) => _ChatTile(
                              item: rows[i],
                              onTap: () => _open(rows[i]),
                            ),
                          );
                        },
                      );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chatListProvider);
    final collapsed = ref.watch(navCollapsedProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ChatScaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _searching
                      ? Padding(
                          key: const ValueKey('search'),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 52,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(26),
                                    border: Border.all(
                                      color: const Color(0xFFDDE3F3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.search_rounded,
                                        size: 22,
                                        color: ChatColors.muted,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: _searchController,
                                          autofocus: true,
                                          textInputAction:
                                              TextInputAction.search,
                                          onChanged: (v) =>
                                              setState(() => _query = v),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: ChatColors.ink,
                                          ),
                                          decoration:
                                              const InputDecoration.collapsed(
                                            hintText: 'Cari percakapan',
                                            hintStyle: TextStyle(
                                              fontSize: 15,
                                              color: ChatColors.hint,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ChatCircleButton(
                                icon: Icons.close_rounded,
                                size: 52,
                                iconSize: 24,
                                onTap: _closeSearch,
                              ),
                            ],
                          ),
                        )
                      : Padding(
                          key: const ValueKey('title'),
                          padding: const EdgeInsets.fromLTRB(24, 14, 16, 0),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Chat',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: ChatColors.ink,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              ChatCircleButton(
                                icon: Icons.search_rounded,
                                size: 52,
                                iconSize: 26,
                                onTap: _openSearch,
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _Segmented(
                    listenable: _pages,
                    position: () => _pages.hasClients && _pages.page != null
                        ? _pages.page!
                        : _filter.index.toDouble(),
                    labels: const ['Semua', 'Pribadi', 'Market'],
                    onChanged: (i) => _pages.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    child: NotificationListener<UserScrollNotification>(
                      onNotification: _onScroll,
                      child: PageView(
                        controller: _pages,
                        onPageChanged: (i) =>
                            setState(() => _filter = _Filter.values[i]),
                        children: [
                          for (final f in _Filter.values)
                            _buildPage(async, f, bottom),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // FAB tulis pesan: di atas kapsul navigasi saat penuh, lalu turun
          // sejajar lingkaran (digambar MainShell) saat navigasi menyusut.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeInOutCubic,
            right: collapsed ? kNavCollapsedLeft : kNavSideGap + 4,
            bottom: collapsed
                ? navCircleBottom(context)
                : navBottomGap(context) + kNavHeight + 16,
            child: Material(
              color: ChatColors.blue,
              shape: const CircleBorder(),
              elevation: 6,
              shadowColor: ChatColors.blue.withValues(alpha: .45),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _newDm,
                child: const SizedBox(
                  width: kNavCircle,
                  height: kNavCircle,
                  child: Icon(
                    Icons.edit_square,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Segmented control: Semua | Pribadi | Market. Pil biru mengikuti posisi
/// geser PageView (bisa pecahan saat digeser), jadi ikut bergerak mulus.
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.listenable,
    required this.position,
    required this.labels,
    required this.onChanged,
  });

  final Listenable listenable;
  final double Function() position;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1E3A8A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / labels.length;
          return ListenableBuilder(
            listenable: listenable,
            builder: (context, _) {
              final pos = position().clamp(0.0, labels.length - 1.0);
              final active = pos.round();
              return Stack(
                children: [
                  Positioned(
                    left: w * pos,
                    top: 0,
                    bottom: 0,
                    width: w,
                    child: Container(
                      decoration: BoxDecoration(
                        color: ChatColors.segBlue,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: ChatColors.segBlue.withValues(alpha: .35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < labels.length; i++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onChanged(i),
                            child: Center(
                              child: Text(
                                labels[i],
                                style: TextStyle(
                                  fontFamily: kChatFont,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: i == active
                                      ? Colors.white
                                      : ChatColors.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.item, required this.onTap});

  final ChatListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = userById(item.userId);
    final unread = item.unread > 0;
    final isMarket = item.kind == ChatKind.market;
    final roleTone = item.role == 'Jual' ? ChatTone.info : ChatTone.danger;
    final rc = toneColors(roleTone);
    final sc = toneColors(item.statusTone);
    final wc = toneColors(ChatTone.warning);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChatAvatar(user: user, size: 48, showOnline: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: ChatColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        chatListTime(item.time),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: unread ? ChatColors.blue : ChatColors.muted,
                        ),
                      ),
                    ],
                  ),
                  if (isMarket || item.isRequest) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (isMarket && item.role != null)
                          ChatPill(
                            label: item.role!,
                            background: rc.bg,
                            foreground: rc.fg,
                          ),
                        if (isMarket && item.statusLabel != null)
                          ChatPill(
                            label: item.statusLabel!,
                            background: sc.bg,
                            foreground: sc.fg,
                          ),
                        if (item.isRequest)
                          ChatPill(
                            label: 'Permintaan pesan',
                            background: wc.bg,
                            foreground: wc.fg,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.typing ? 'Sedang mengetik...' : item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: unread && !item.typing
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: item.typing
                                ? ChatColors.blue
                                : (unread ? ChatColors.ink : ChatColors.text2),
                          ),
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(minWidth: 24),
                          height: 24,
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: ChatColors.segBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.unread > 99 ? '99+' : '${item.unread}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ] else if (item.lastFromMe) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.done_all_rounded,
                          size: 20,
                          color: item.lastRead
                              ? ChatColors.blue
                              : const Color(0xFF7C879B),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactPickerSheet extends StatelessWidget {
  const _ContactPickerSheet();

  @override
  Widget build(BuildContext context) {
    final users = kFakeUsers.values.where((u) => u.id != kMeId).toList();
    return ChatSheetFrame(
      title: 'Kirim pesan baru',
      subtitle: 'Pilih orang yang ingin kamu ajak chat.',
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (final u in users)
              InkWell(
                onTap: () => Navigator.of(context).pop(u.id),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      ChatAvatar(user: u, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u.name,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: ChatColors.ink,
                              ),
                            ),
                            Text(
                              '@${u.username}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: ChatColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}