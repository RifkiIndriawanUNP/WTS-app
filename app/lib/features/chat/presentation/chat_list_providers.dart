import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wts/core/session/session.dart';
import 'package:wts/features/chat/domain/chat_models.dart';
import 'package:wts/features/chat/domain/dm.dart';
import 'package:wts/features/chat/presentation/dm_providers.dart';
import 'package:wts/features/chat/domain/market_chat.dart';
import 'package:wts/features/chat/presentation/market_chat_providers.dart';
import 'package:wts/features/chat/presentation/chat_ui.dart';
import 'package:wts/shared/models/app_user.dart';

({String label, ChatTone tone}) _marketStatus(MarketChat c, String me) {
  switch (c.status) {
    case MarketChatStatus.negotiating:
      final o = c.pendingOffer;
      if (o == null) return (label: 'Negosiasi', tone: ChatTone.warning);
      return o.fromUser == me
          ? (label: 'Menunggu jawaban', tone: ChatTone.warning)
          : (label: 'Perlu dijawab', tone: ChatTone.warning);
    case MarketChatStatus.agreed:
      final at = c.meetAt;
      return (
        label: at == null ? 'Sepakat' : 'Terjadwal · ${slotLabel(at)}',
        tone: ChatTone.info,
      );
    case MarketChatStatus.onTheWay:
      return (label: 'Dalam perjalanan', tone: ChatTone.info);
    case MarketChatStatus.arrived:
      return (label: 'Di titik temu', tone: ChatTone.info);
    case MarketChatStatus.sold:
      return (label: 'Selesai', tone: ChatTone.success);
    case MarketChatStatus.cancelled:
      return (label: 'Dibatalkan', tone: ChatTone.muted);
    case MarketChatStatus.closed:
      return (label: 'Ditutup', tone: ChatTone.muted);
  }
}

String _marketPreview(MarketChat c, String me) {
  final m = c.lastMessage;
  if (m == null) return 'Belum ada pesan';
  if (m.type == MessageType.offer) {
    if (m.senderId == me) return 'Kamu mengirimkan kesepakatan';
    return '${firstName(userById(m.senderId ?? ''))} mengirim kesepakatan';
  }
  return m.preview;
}

ChatListItem _marketItem(MarketChat c, String me) {
  final status = _marketStatus(c, me);
  return ChatListItem(
    kind: ChatKind.market,
    id: c.id,
    userId: c.otherId(me),
    title: userById(c.otherId(me)).name,
    subtitle: _marketPreview(c, me),
    time: c.lastActivityAt,
    unread: c.unread,
    role: c.sellerId == me ? 'Jual' : 'Beli',
    statusLabel: status.label,
    statusTone: status.tone,
    lastFromMe: c.lastMessage?.senderId == me,
    lastRead: c.lastMessage?.readByOther ?? false,
  );
}

/// Gabungan DM + chat market untuk tab Chat (terbaru di atas).
/// Catatan: jurusan sengaja tidak ditampilkan di daftar chat.
final chatListProvider = Provider<AsyncValue<List<ChatListItem>>>((ref) {
  final me = ref.watch(currentUserProvider).id;
  final dms = ref.watch(dmConversationsProvider);
  final markets = ref.watch(marketChatsProvider);

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
        subtitle: c.lastMessage == null ? 'Belum ada pesan' : c.lastMessage!.preview,
        time: c.lastMessageAt,
        unread: c.unread,
        isRequest: c.status == DmStatus.request && c.requesterId != me,
        typing: c.peerTyping,
        lastFromMe: c.lastMessage?.senderId == me,
        lastRead: c.lastMessage?.readByOther ?? false,
      ),
    for (final c in marketList) _marketItem(c, me),
  ]..sort((a, b) => b.time.compareTo(a.time));

  return AsyncData(items);
});

/// Jumlah transaksi market yang masih berjalan (badge tas di header Chat).
final activeDealCountProvider = Provider<int>((ref) {
  final list = ref.watch(marketChatsProvider).value ?? const <MarketChat>[];
  return list
      .where(
        (c) =>
            c.status == MarketChatStatus.negotiating ||
            c.isActiveDeal,
      )
      .length;
});

/// Total pesan belum dibaca (badge tab Chat).
final unreadChatCountProvider = Provider<int>((ref) {
  final items = ref.watch(chatListProvider).value ?? const [];
  return items.fold<int>(0, (sum, i) => sum + i.unread);
});