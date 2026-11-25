import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wts/core/theme/app_theme.dart';
import 'package:wts/core/utils/format.dart';
import 'package:wts/core/utils/guard.dart';
import 'package:wts/features/chat/domain/chat_models.dart';
import 'package:wts/features/chat/presentation/chat_list_providers.dart';
import 'package:wts/features/chat/presentation/dm_providers.dart';
import 'package:wts/features/chat/presentation/market_chat_providers.dart';
import 'package:wts/shared/models/app_user.dart';
import 'package:wts/shared/widgets/common_widgets.dart';
import 'package:wts/shared/widgets/glass.dart';

enum _Filter { all, dm, market }

class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(ChatListItem item) {
    context.push(
      item.kind == ChatKind.market
          ? '/chat/market/${item.id}'
          : '/chat/dm/${item.id}',
    );
  }

  Future<void> _newDm() async {
    final userId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ContactPickerSheet(),
    );
    if (userId == null || !mounted) return;
    final id = await guarded(
      context,
      () => ref.read(dmRepositoryProvider).startDm(userId),
    );
    if (id != null && mounted) context.push('/chat/dm/$id');
  }

  List<Object> _rows(List<ChatListItem> source) {
    final q = _query.toLowerCase();
    final filtered = source.where((i) {
      if (_filter == _Filter.dm && i.kind != ChatKind.dm) return false;
      if (_filter == _Filter.market && i.kind != ChatKind.market) return false;
      if (q.isEmpty) return true;
      return '${i.title} ${i.subtitle} ${i.productTitle ?? ''}'
          .toLowerCase()
          .contains(q);
    }).toList();

    if (_filter != _Filter.market) return filtered;
    final buyer = filtered.where((i) => i.role == 'Pembeli').toList();
    final seller = filtered.where((i) => i.role == 'Penjual').toList();
    return [
      if (buyer.isNotEmpty) ...['Sebagai Pembeli', ...buyer],
      if (seller.isNotEmpty) ...['Sebagai Penjual', ...seller],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chatListProvider);

    return GlassScaffold(
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: navSpace(context) - 24),
        child: FloatingActionButton(
          heroTag: 'chat_fab',
          onPressed: _newDm,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          child: const Icon(Icons.edit_rounded),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const GlassHeader(title: 'Chat'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassSearchField(
                controller: _search,
                hint: 'Cari percakapan',
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  GlassChip(
                    label: 'Semua',
                    selected: _filter == _Filter.all,
                    onTap: () => setState(() => _filter = _Filter.all),
                  ),
                  const SizedBox(width: 8),
                  GlassChip(
                    label: 'Pribadi',
                    selected: _filter == _Filter.dm,
                    onTap: () => setState(() => _filter = _Filter.dm),
                  ),
                  const SizedBox(width: 8),
                  GlassChip(
                    label: 'Jual-Beli',
                    selected: _filter == _Filter.market,
                    onTap: () => setState(() => _filter = _Filter.market),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: async.when(
                loading: () => ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: 6,
                  separatorBuilder: (context, i) => const SizedBox(height: 10),
                  itemBuilder: (context, i) =>
                      const SkeletonBox(height: 72, radius: 20),
                ),
                error: (e, _) => ErrorState(
                  onRetry: () {
                    ref.invalidate(dmConversationsProvider);
                    ref.invalidate(marketChatsProvider);
                  },
                ),
                data: (items) {
                  final rows = _rows(items);
                  if (rows.isEmpty) {
                    return EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: _query.isEmpty
                          ? 'Belum ada percakapan'
                          : 'Tidak ada hasil',
                      message: _query.isEmpty
                          ? 'Mulai chat dari produk di Market atau tekan tombol pensil.'
                          : 'Coba kata kunci lain.',
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      navSpace(context) + 56,
                    ),
                    itemCount: rows.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      if (row is String) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            row,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.muted,
                            ),
                          ),
                        );
                      }
                      final item = row as ChatListItem;
                      return _ChatTile(item: item, onTap: () => _open(item));
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
    return GlassCard(
      blur: 0,
      radius: 20,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          UserAvatar(user: user, size: 50, showOnline: true),
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
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      listTime(item.time),
                      style: TextStyle(
                        fontSize: 11,
                        color: unread ? AppColors.primary : AppColors.muted,
                      ),
                    ),
                  ],
                ),
                if (item.productTitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${item.role} • ${item.productTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unread ? AppColors.ink : AppColors.muted,
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (item.isRequest) ...[
                      const SizedBox(width: 6),
                      const StatusPill(
                        label: 'Permintaan',
                        color: AppColors.warning,
                      ),
                    ],
                    if (item.statusLabel != null) ...[
                      const SizedBox(width: 6),
                      StatusPill(
                        label: item.statusLabel!,
                        color: Color(item.statusColorValue ?? 0xFF6B7280),
                      ),
                    ],
                    if (unread) ...[
                      const SizedBox(width: 6),
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          '${item.unread}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactPickerSheet extends StatelessWidget {
  const _ContactPickerSheet();

  @override
  Widget build(BuildContext context) {
    final users = kFakeUsers.values.where((u) => u.id != kMeId).toList();
    return GlassSheet(
      title: 'Kirim pesan baru',
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (final u in users)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: UserAvatar(user: u, size: 42),
                title: Text(
                  u.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(u.major ?? '@${u.username}'),
                onTap: () => Navigator.of(context).pop(u.id),
              ),
          ],
        ),
      ),
    );
  }
}
