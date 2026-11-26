import 'package:wts/features/chat/domain/chat_models.dart';

enum MarketChatStatus {
  negotiating,
  agreed,
  onTheWay,
  arrived,
  sold,
  cancelled,
  closed,
}

enum OfferStatus { pending, accepted, rejected, countered, expired }

enum OfferAction { accept, reject, counter }

enum ChatProgress { departed, arrived }

class Offer {
  const Offer({
    required this.id,
    required this.fromUser,
    required this.price,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.meetAt,
    this.place,
    this.rejectReason,
  });

  final String id;
  final String fromUser;
  final int price;
  final OfferStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// Waktu & tempat COD yang diusulkan bersama harga (satu paket kesepakatan).
  final DateTime? meetAt;
  final String? place;

  /// Alasan penolakan (diisi saat status rejected).
  final String? rejectReason;

  bool get isExpired =>
      status == OfferStatus.pending && DateTime.now().isAfter(expiresAt);

  OfferStatus get effectiveStatus => isExpired ? OfferStatus.expired : status;

  bool get isActivePending => effectiveStatus == OfferStatus.pending;

  Offer copyWith({OfferStatus? status, String? rejectReason}) => Offer(
        id: id,
        fromUser: fromUser,
        price: price,
        status: status ?? this.status,
        createdAt: createdAt,
        expiresAt: expiresAt,
        meetAt: meetAt,
        place: place,
        rejectReason: rejectReason ?? this.rejectReason,
      );
}

const _unset = Object();

class MarketChat {
  const MarketChat({
    required this.id,
    required this.productId,
    required this.buyerId,
    required this.sellerId,
    required this.status,
    required this.lastActivityAt,
    required this.messages,
    required this.offers,
    this.agreedPrice,
    this.soldAt,
    this.cancelledAt,
    this.deleteAt,
    this.unread = 0,
    this.ratedByMe = false,
    this.meetAt,
    this.place,
    this.departed = const {},
    this.arrived = const {},
  });

  final String id;
  final String productId;
  final String buyerId;
  final String sellerId;
  final MarketChatStatus status;
  final DateTime lastActivityAt;
  final List<ChatMessage> messages;
  final List<Offer> offers;
  final int? agreedPrice;
  final DateTime? soldAt;
  final DateTime? cancelledAt;

  /// Kapan chat ini dihapus otomatis (null = belum dijadwalkan).
  final DateTime? deleteAt;
  final int unread;
  final bool ratedByMe;

  /// Jadwal & titik temu hasil kesepakatan.
  final DateTime? meetAt;
  final String? place;

  /// Kapan masing-masing pihak (id pengguna) menandai berangkat / sampai.
  final Map<String, DateTime> departed;
  final Map<String, DateTime> arrived;

  DateTime? get firstDepartedAt {
    if (departed.isEmpty) return null;
    final list = departed.values.toList()..sort();
    return list.first;
  }

  DateTime? get firstArrivedAt {
    if (arrived.isEmpty) return null;
    final list = arrived.values.toList()..sort();
    return list.first;
  }

  DateTime? get lastArrivedAt {
    if (arrived.isEmpty) return null;
    final list = arrived.values.toList()..sort();
    return list.last;
  }

  bool get bothArrived => arrived.length >= 2;

  String otherId(String meId) => buyerId == meId ? sellerId : buyerId;

  bool get isActiveDeal =>
      status == MarketChatStatus.agreed ||
      status == MarketChatStatus.onTheWay ||
      status == MarketChatStatus.arrived;

  /// Input chat dimatikan bila dibatalkan / ditutup.
  bool get isReadOnly =>
      status == MarketChatStatus.cancelled || status == MarketChatStatus.closed;

  Offer? get pendingOffer {
    for (final o in offers) {
      if (o.isActivePending) return o;
    }
    return null;
  }

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  MarketChat copyWith({
    MarketChatStatus? status,
    DateTime? lastActivityAt,
    List<ChatMessage>? messages,
    List<Offer>? offers,
    Object? agreedPrice = _unset,
    Object? soldAt = _unset,
    Object? cancelledAt = _unset,
    Object? deleteAt = _unset,
    int? unread,
    bool? ratedByMe,
    DateTime? meetAt,
    String? place,
    Map<String, DateTime>? departed,
    Map<String, DateTime>? arrived,
  }) {
    return MarketChat(
      id: id,
      productId: productId,
      buyerId: buyerId,
      sellerId: sellerId,
      status: status ?? this.status,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      messages: messages ?? this.messages,
      offers: offers ?? this.offers,
      agreedPrice: identical(agreedPrice, _unset)
          ? this.agreedPrice
          : agreedPrice as int?,
      soldAt: identical(soldAt, _unset) ? this.soldAt : soldAt as DateTime?,
      cancelledAt: identical(cancelledAt, _unset)
          ? this.cancelledAt
          : cancelledAt as DateTime?,
      deleteAt:
          identical(deleteAt, _unset) ? this.deleteAt : deleteAt as DateTime?,
      unread: unread ?? this.unread,
      ratedByMe: ratedByMe ?? this.ratedByMe,
      meetAt: meetAt ?? this.meetAt,
      place: place ?? this.place,
      departed: departed ?? this.departed,
      arrived: arrived ?? this.arrived,
    );
  }
}

String marketStatusLabel(MarketChatStatus s) {
  switch (s) {
    case MarketChatStatus.negotiating:
      return 'Negosiasi';
    case MarketChatStatus.agreed:
      return 'Sepakat';
    case MarketChatStatus.onTheWay:
      return 'Berangkat';
    case MarketChatStatus.arrived:
      return 'Sampai';
    case MarketChatStatus.sold:
      return 'Terjual';
    case MarketChatStatus.cancelled:
      return 'Dibatalkan';
    case MarketChatStatus.closed:
      return 'Ditutup';
  }
}