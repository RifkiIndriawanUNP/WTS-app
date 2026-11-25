import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wts/core/session/session.dart';
import 'package:wts/core/theme/app_theme.dart';
import 'package:wts/features/chat/domain/chat_models.dart';
import 'package:wts/features/chat/domain/dm.dart';
import 'package:wts/features/chat/presentation/dm_providers.dart';
import 'package:wts/features/chat/domain/market_chat.dart';
import 'package:wts/features/chat/presentation/market_chat_providers.dart';
import 'package:wts/features/market/presentation/market_providers.dart';
import 'package:wts/shared/models/app_user.dart';

int _statusColor(MarketChatStatus s) {
  switch (s) {
    case MarketChatStatus.negotiating:
      return AppColors.warning.toARGB32();
    case MarketChatStatus.agreed:
    case MarketChatStatus.onTheWay:
    case MarketChatStatus.arrived:
      return AppColors.primary.toARGB32();
    case MarketChatStatus.sold:
      return AppColors.success.toARGB32();
    case MarketChatStatus.cancelled:
    case MarketChatStatus.closed:
      return AppColors.muted.toARGB32();
  }
}

/// Gabungan DM + chat market untuk tab Chat (terbaru di atas).
final chatListProvider = Provider<AsyncValue<List<ChatListItem>>>((ref) {
  final me = ref.watch(currentUserProvider).id;
  final dms = ref.watch(dmConversationsProvider);
  final markets = ref.watch(marketChatsProvider);
  final products = ref.watch(productsProvider).value ?? const [];

  if (dms.hasError) {
    return AsyncError<List<ChatListItem>>(dms.error!, dms.stackTrace!);
  }
  if (markets.hasError) {
    return AsyncError<List<ChatListItem>>(markets.error!, markets.stackTrace!);
  }
  final dmList = dms.value;
  final marketList = markets.value;
  if (dmList == null || marketList == null) {
    return const AsyncLoading<List<ChatListItem>>();
  }

  final items = <ChatListItem>[
    for (final c in dmList)
      ChatListItem(
        kind: ChatKind.dm,
        id: c.id,
        userId: c.otherId,
        title: userById(c.otherId).name,
        subtitle: c.lastMessage == null
            ? 'Belum ada pesan'
            : (c.lastMessage!.senderId == me ? 'Kamu: ' : '') +
                c.lastMessage!.preview,
        time: c.lastMessageAt,
        unread: c.unread,
        isRequest: c.status == DmStatus.request && c.requesterId != me,
      ),
    for (final c in marketList)
      ChatListItem(
        kind: ChatKind.market,
        id: c.id,
        userId: c.otherId(me),
        title: userById(c.otherId(me)).name,
        subtitle: c.lastMessage == null
            ? 'Belum ada pesan'
            : (c.lastMessage!.senderId == me ? 'Kamu: ' : '') +
                c.lastMessage!.preview,
        time: c.lastActivityAt,
        unread: c.unread,
        productTitle:
            products.where((p) => p.id == c.productId).firstOrNull?.title ??
                'Produk',
        role: c.sellerId == me ? 'Penjual' : 'Pembeli',
        statusLabel: marketStatusLabel(c.status),
        statusColorValue: _statusColor(c.status),
      ),
  ]..sort((a, b) => b.time.compareTo(a.time));

  return AsyncData(items);
});

/// Total pesan belum dibaca (badge tab Chat).
final unreadChatCountProvider = Provider<int>((ref) {
  final items = ref.watch(chatListProvider).value ?? const [];
  return items.fold<int>(0, (sum, i) => sum + i.unread);
});
