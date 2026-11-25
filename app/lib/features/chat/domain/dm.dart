import 'package:wts/features/chat/domain/chat_models.dart';

enum DmStatus { request, accepted }

class DmConversation {
  const DmConversation({
    required this.id,
    required this.otherId,
    required this.requesterId,
    required this.status,
    required this.messages,
    required this.lastMessageAt,
    this.unread = 0,
  });

  final String id;
  final String otherId;

  /// Pengguna yang memulai percakapan (pengirim "Permintaan Pesan").
  final String requesterId;
  final DmStatus status;
  final List<ChatMessage> messages;
  final DateTime lastMessageAt;
  final int unread;

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  DmConversation copyWith({
    DmStatus? status,
    List<ChatMessage>? messages,
    DateTime? lastMessageAt,
    int? unread,
  }) {
    return DmConversation(
      id: id,
      otherId: otherId,
      requesterId: requesterId,
      status: status ?? this.status,
      messages: messages ?? this.messages,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unread: unread ?? this.unread,
    );
  }
}

/// Kontrak DM. Nanti dipetakan ke RPC: start_dm, accept_dm, send_message, dst.
abstract class DmRepository {
  Stream<List<DmConversation>> watchConversations();

  Stream<DmConversation?> watchConversation(String id);

  /// Buat atau buka percakapan dengan [userId].
  /// Gagal bila DM dinonaktifkan / diblokir / melebihi 20 percakapan baru/hari.
  Future<String> startDm(String userId);

  Future<void> accept(String id);

  /// Abaikan permintaan (percakapan dihapus dari daftar).
  Future<void> ignore(String id);

  /// Blokir pengirim (percakapan dihapus).
  Future<void> block(String id);

  Future<void> send(
    String id,
    MessageType type, {
    String? body,
    Map<String, Object?> meta = const {},
  });

  Future<void> deleteMessage(String id, String messageId);

  Future<void> markRead(String id);
}
