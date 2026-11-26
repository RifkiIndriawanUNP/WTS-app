import 'dart:typed_data';

enum ListingType { sell, rent, free }

enum ItemCondition { brandNew, used }

enum ProductStatus { available, booked, sold }

/// Serah terima barang (filter "Serah terima" & detail produk).
enum Handover { codKampus, barangBesar }

extension HandoverLabel on Handover {
  String get label =>
      this == Handover.codKampus ? 'COD kampus' : 'Barang besar';
}

extension ListingTypeLabel on ListingType {
  /// Label pada tab / filter ("Dijual", "Disewakan", "Gratis").
  String get label {
    switch (this) {
      case ListingType.sell:
        return 'Dijual';
      case ListingType.rent:
        return 'Disewakan';
      case ListingType.free:
        return 'Gratis';
    }
  }

  /// Label pada tag kartu ("Dijual", "Sewa", "Gratis").
  String get tagLabel => this == ListingType.rent ? 'Sewa' : label;
}

const kProductCategories = <String>[
  'IoT',
  'Buku',
  'Elektronik',
  'Perabot',
  'Kos',
  'Jasa',
  'Lainnya',
];

const kRentUnits = <String>['hari', 'minggu', 'bulan', 'semester'];

const kMeetingPoints = <String>[
  'Perpustakaan',
  'Kantin',
  'Lobby Gedung',
  'Masjid Kampus',
  'Taman Kampus',
];

class Product {
  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.listingType,
    required this.condition,
    required this.category,
    required this.meetingPoint,
    required this.sellerId,
    required this.createdAt,
    required this.expiresAt,
    this.rentUnit,
    this.deposit,
    this.defectNote,
    this.negotiable = true,
    this.handover = Handover.codKampus,
    this.likeCount = 0,
    this.imageCount = 1,
    this.imageUrls = const [],
    this.photoBytesList = const [],
    this.status = ProductStatus.available,
    this.extensionCount = 0,
  });

  final String id;
  final String title;
  final String description;
  final int price;
  final ListingType listingType;
  final ItemCondition condition;
  final String category;
  final String meetingPoint;
  final String sellerId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? rentUnit;
  final int? deposit;
  final String? defectNote;
  final bool negotiable;
  final Handover handover;
  final int likeCount;
  final int imageCount;
  final List<String> imageUrls;

  final List<Uint8List> photoBytesList;
  final ProductStatus status;
  final int extensionCount;

  bool get isRent => listingType == ListingType.rent;
  bool get isFree => listingType == ListingType.free;
  bool get isUsed => condition == ItemCondition.used;
  bool get isSold => status == ProductStatus.sold;

  /// "Rp 145.000" atau "Rp 25.000 /hari" (spasi sesuai desain).
  String get priceLabel {
    final base = rp(isFree ? 0 : price);
    return isRent ? '$base /$rentUnit' : base;
  }

  String get statusLabel {
    switch (status) {
      case ProductStatus.available:
        return 'Tersedia';
      case ProductStatus.booked:
        return 'Dipesan';
      case ProductStatus.sold:
        return isRent ? 'Disewa' : 'Terjual';
    }
  }

  int get seed => id.codeUnits.fold<int>(0, (a, b) => a + b);

  int get totalImages {
    if (photoBytesList.isNotEmpty) return photoBytesList.length;
    if (imageUrls.isNotEmpty) return imageUrls.length;
    return imageCount;
  }

  Product copyWith({
    ProductStatus? status,
    DateTime? expiresAt,
    int? extensionCount,
    int? likeCount,
    List<String>? imageUrls,
    List<Uint8List>? photoBytesList,
  }) {
    return Product(
      id: id,
      title: title,
      description: description,
      price: price,
      listingType: listingType,
      condition: condition,
      category: category,
      meetingPoint: meetingPoint,
      sellerId: sellerId,
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rentUnit: rentUnit,
      deposit: deposit,
      defectNote: defectNote,
      negotiable: negotiable,
      handover: handover,
      likeCount: likeCount ?? this.likeCount,
      imageCount: imageCount,
      imageUrls: imageUrls ?? this.imageUrls,
      photoBytesList: photoBytesList ?? this.photoBytesList,
      status: status ?? this.status,
      extensionCount: extensionCount ?? this.extensionCount,
    );
  }
}

String _group(int value) {
  final digits = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// 145000 -> "Rp 145.000" (dipakai di UI Market; spasi sesuai desain).
String rp(num value) => 'Rp ${_group(value.round())}';

/// Isi formulir "Posting Barang".
class NewProductInput {
  const NewProductInput({
    required this.title,
    required this.description,
    required this.price,
    required this.listingType,
    required this.condition,
    required this.category,
    required this.meetingPoint,
    required this.imageCount,
    this.imageUrls = const [],
    this.photoBytesList = const [],
    this.rentUnit,
    this.deposit,
    this.defectNote,
    this.negotiable = true,
    this.handover = Handover.codKampus,
  });

  final String title;
  final String description;
  final int price;
  final ListingType listingType;
  final ItemCondition condition;
  final String category;
  final String meetingPoint;
  final int imageCount;
  final List<String> imageUrls;
  final List<Uint8List> photoBytesList;
  final String? rentUnit;
  final int? deposit;
  final String? defectNote;
  final bool negotiable;
  final Handover handover;
}