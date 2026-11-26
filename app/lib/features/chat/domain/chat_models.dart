enum MessageType { text, image, location, contact, link, offer, system }

/// Fungsi kirim pesan yang dipakai bersama oleh DM dan chat market.
typedef SendMessageFn = Future<void> Function(
  MessageType type, {
  String? body,
  Map<String, Object?>? meta,
});

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.type,
    required this.createdAt,
    this.senderId,
    this.body,
    this.meta = const {},
    this.readByOther = false,
  });

  final String id;

  /// null = pesan sistem.
  final String? senderId;
  final MessageType type;
  final String? body;
  final Map<String, Object?> meta;
  final DateTime createdAt;
  final bool readByOther;

  bool get isSystem => type == MessageType.system;

  /// Teks ringkas untuk pratinjau di daftar chat.
  String get preview {
    switch (type) {
      case MessageType.text:
      case MessageType.system:
        return body ?? '';
      case MessageType.image:
        return 'Foto';
      case MessageType.location:
        return 'Lokasi';
      case MessageType.contact:
        return 'Kontak WhatsApp';
      case MessageType.link:
        return body ?? 'Tautan';
      case MessageType.offer:
        return 'Tawaran ${body ?? ''}';
    }
  }
}

/// Satu baris di tab Chat (gabungan DM + chat market).
enum ChatKind { dm, market }

/// Warna semantik chip status di daftar chat.
enum ChatTone { info, warning, success, danger, muted }

class ChatListItem {
  const ChatListItem({
    required this.kind,
    required this.id,
    required this.userId,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.unread,
    this.role,
    this.statusLabel,
    this.statusTone = ChatTone.muted,
    this.isRequest = false,
    this.typing = false,
    this.lastFromMe = false,
    this.lastRead = false,
  });

  final ChatKind kind;
  final String id;
  final String userId;
  final String title;
  final String subtitle;
  final DateTime time;
  final int unread;

  /// 'Jual' / 'Beli' (khusus chat market).
  final String? role;
  final String? statusLabel;
  final ChatTone statusTone;
  final bool isRequest;

  /// Lawan bicara sedang mengetik.
  final bool typing;

  /// Pesan terakhir dikirim oleh saya (tampilkan centang) dan sudah dibaca?
  final bool lastFromMe;
  final bool lastRead;
}