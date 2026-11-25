import 'dart:typed_data';

import 'package:wts/core/utils/format.dart';

enum ListingType { sell, rent }

enum ItemCondition { brandNew, used }

enum ProductStatus { available, booked, sold }

const kProductCategories = <String>[
  'IoT',
  'Buku/Modul',
  'Alat Praktikum',
  'Jas Lab',
  'Laptop & Aksesoris',
  'Elektronik',
  'Alat Tulis/Gambar',
  'Perlengkapan Kos',
  'Pakaian/Almamater',
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
  final int imageCount;
  final List<String> imageUrls;
  final List<Uint8List> photoBytesList;
  final ProductStatus status;
  final int extensionCount;

  bool get isRent => listingType == ListingType.rent;
  bool get isUsed => condition == ItemCondition.used;
  bool get isSold => status == ProductStatus.sold;

  String get priceLabel =>
      isRent ? '${formatRp(price)} /$rentUnit' : formatRp(price);

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

  Product copyWith({
    ProductStatus? status,
    DateTime? expiresAt,
    int? extensionCount,
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
      imageCount: imageCount,
      imageUrls: imageUrls ?? this.imageUrls,
      photoBytesList: photoBytesList ?? this.photoBytesList,
      status: status ?? this.status,
      extensionCount: extensionCount ?? this.extensionCount,
    );
  }
}

/// Isi formulir "Tambah Barang".
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
}