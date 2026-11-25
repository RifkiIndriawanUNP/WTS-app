import 'package:wts/features/chat/domain/chat_models.dart';
import 'package:wts/features/chat/domain/market_chat.dart';

/// Kontrak chat market (COD). Implementasi palsu: data/fake_market_chat_repository.dart.
/// Nanti dipetakan ke RPC: open_market_chat, send_offer, respond_offer,
/// set_chat_progress, mark_sold, cancel_market_chat, rate_deal, mark_read.
abstract class MarketChatRepository {
  Stream<List<MarketChat>> watchChats();

  Stream<MarketChat?> watchChat(String id);

  /// Buka chat yang sudah ada (produk + pembeli) atau buat baru.
  Future<String> openChat(String productId);

  Future<void> sendMessage(
    String chatId,
    MessageType type, {
    String? body,
    Map<String, Object?> meta = const {},
  });

  Future<void> deleteMessage(String chatId, String messageId);

  Future<void> sendOffer(String chatId, int price);

  Future<void> respondOffer(
    String chatId,
    String offerId,
    OfferAction action, {
    int? counterPrice,
  });

  Future<void> setProgress(String chatId, ChatProgress step);

  Future<void> markSold(String chatId);

  Future<void> cancel(String chatId, String reason);

  Future<void> rate(String chatId, int stars, String? comment);

  Future<void> markRead(String chatId);
}
