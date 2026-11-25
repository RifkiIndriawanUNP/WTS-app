import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wts/core/session/session.dart';
import 'package:wts/features/chat/data/fake_market_chat_repository.dart';
import 'package:wts/features/chat/domain/market_chat.dart';
import 'package:wts/features/chat/domain/market_chat_repository.dart';
import 'package:wts/features/market/presentation/market_providers.dart';
import 'package:wts/features/notifications/data/fake_notification_repository.dart';
import 'package:wts/features/notifications/presentation/notification_providers.dart';

/// Sementara memakai repository palsu. Nanti diganti implementasi Supabase.
final marketChatRepositoryProvider = Provider<MarketChatRepository>((ref) {
  return FakeMarketChatRepository(
    market: ref.read(marketRepositoryProvider),
    meId: ref.read(currentUserProvider).id,
    onNotify: (type, category, title, body, actorId, route) {
      final repo = ref.read(notificationRepositoryProvider);
      if (repo is FakeNotificationRepository) {
        repo.add(
          type: type,
          category: category,
          title: title,
          body: body,
          actorId: actorId,
          route: route,
        );
      }
    },
  );
});

final marketChatsProvider = StreamProvider<List<MarketChat>>(
  (ref) => ref.watch(marketChatRepositoryProvider).watchChats(),
);

final marketChatProvider = StreamProvider.family<MarketChat?, String>(
  (ref, id) => ref.watch(marketChatRepositoryProvider).watchChat(id),
);
