/// Tahap COD pada kartu "Transaksi Saya": Sepakat -> Berangkat -> Sampai -> Terjual.
const kTransactionStages = <String>['Sepakat', 'Berangkat', 'Sampai', 'Terjual'];

enum TransactionPhase { ongoing, done, cancelled }

enum TransactionInfoKind { schedule, deadline }

class MarketTransaction {
  const MarketTransaction({
    required this.id,
    required this.title,
    required this.counterpart,
    required this.isSeller,
    required this.price,
    required this.stage,
    required this.phase,
    required this.badge,
    required this.infoKind,
    required this.infoText,
    this.productId,
    this.awaitingReply = false,
  });

  final String id;
  final String? productId;
  final String title;

  /// Nama lawan transaksi (pembeli/penjual).
  final String counterpart;

  /// true = "Jual" (aku penjual), false = "Beli".
  final bool isSeller;
  final int price;

  /// 0..3 indeks [kTransactionStages].
  final int stage;
  final TransactionPhase phase;

  /// Teks chip status ("Terjadwal", "Menunggu jawaban", ...).
  final String badge;
  final TransactionInfoKind infoKind;
  final String infoText;

  /// true = tawaran belum dijawab (tampilan oranye + "Lihat Tawaran"/"Batalkan").
  final bool awaitingReply;

  String get roleLabel => isSeller ? 'Jual' : 'Beli';

  String get firstName => counterpart.split(' ').first;

  MarketTransaction copyWith({
    int? stage,
    TransactionPhase? phase,
    String? badge,
    String? infoText,
    TransactionInfoKind? infoKind,
    bool? awaitingReply,
  }) {
    return MarketTransaction(
      id: id,
      productId: productId,
      title: title,
      counterpart: counterpart,
      isSeller: isSeller,
      price: price,
      stage: stage ?? this.stage,
      phase: phase ?? this.phase,
      badge: badge ?? this.badge,
      infoKind: infoKind ?? this.infoKind,
      infoText: infoText ?? this.infoText,
      awaitingReply: awaitingReply ?? this.awaitingReply,
    );
  }
}