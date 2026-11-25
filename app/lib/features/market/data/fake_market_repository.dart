import 'package:wts/core/supabase/failure.dart';
import 'package:wts/core/utils/fake_store.dart';
import 'package:wts/features/market/domain/market_repository.dart';
import 'package:wts/features/market/domain/product.dart';
import 'package:wts/shared/models/app_user.dart';

class FakeMarketRepository implements MarketRepository {
  FakeMarketRepository({String meId = kMeId}) : _meId = meId {
    _items.addAll(_seed());
  }

  final String _meId;
  final List<Product> _items = [];
  final FakeStore _store = FakeStore();
  int _seq = 100;

  List<Product> _snapshot() {
    final now = DateTime.now();
    final list =
        _items.where((p) => p.isSold || p.expiresAt.isAfter(now)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  @override
  Stream<List<Product>> watchProducts() =>
      _store.watch(_snapshot, initialDelay: const Duration(milliseconds: 600));

  @override
  Product? findById(String id) {
    for (final p in _items) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<Product> createProduct(NewProductInput input) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final active = _items
        .where((p) => p.sellerId == _meId && p.status != ProductStatus.sold)
        .length;
    if (active >= 20) {
      throw const Failure('limit_reached', 'Maksimal 20 produk aktif.');
    }
    final now = DateTime.now();
    final count = input.photoBytesList.isNotEmpty
        ? input.photoBytesList.length
        : (input.imageUrls.isNotEmpty ? input.imageUrls.length : input.imageCount);
    final product = Product(
      id: 'p${_seq++}',
      title: input.title,
      description: input.description,
      price: input.price,
      listingType: input.listingType,
      condition: input.condition,
      category: input.category,
      meetingPoint: input.meetingPoint,
      sellerId: _meId,
      createdAt: now,
      expiresAt: now.add(const Duration(days: 30)),
      rentUnit: input.rentUnit,
      deposit: input.deposit,
      defectNote: input.defectNote,
      negotiable: input.negotiable,
      imageCount: count,
      imageUrls: input.imageUrls,
      photoBytesList: input.photoBytesList,
    );
    _items.add(product);
    _store.notify();
    return product;
  }

  Product _own(String id) {
    final p = findById(id);
    if (p == null) {
      throw const Failure('not_found', 'Produk tidak ditemukan.');
    }
    if (p.sellerId != _meId) {
      throw const Failure('forbidden', 'Kamu tidak punya akses.');
    }
    return p;
  }

  void _replace(Product next) {
    final i = _items.indexWhere((p) => p.id == next.id);
    if (i >= 0) _items[i] = next;
    _store.notify();
  }

  @override
  Future<void> extendProduct(String id) async {
    final p = _own(id);
    if (p.extensionCount >= 3) {
      throw const Failure('extension_limit', 'Perpanjangan maksimal 3 kali.');
    }
    _replace(
      p.copyWith(
        expiresAt: p.expiresAt.add(const Duration(days: 30)),
        extensionCount: p.extensionCount + 1,
      ),
    );
  }

  @override
  Future<void> deleteProduct(String id) async {
    _own(id);
    _items.removeWhere((p) => p.id == id);
    _store.notify();
  }

  @override
  Future<void> setStatus(String id, ProductStatus status) async {
    final p = findById(id);
    if (p == null) return;
    _replace(p.copyWith(status: status));
  }

  List<Product> _seed() {
    final now = DateTime.now();
    Product mk({
      required String id,
      required String title,
      required int price,
      required String category,
      required String seller,
      List<String> urls = const [],
      ItemCondition cond = ItemCondition.used,
      ListingType type = ListingType.sell,
      String? rentUnit,
      int? deposit,
      String? defect,
      String? desc,
      int images = 3,
      int ageHours = 5,
      bool nego = true,
      String point = 'Perpustakaan',
      ProductStatus status = ProductStatus.available,
    }) {
      return Product(
        id: id,
        title: title,
        description:
            desc ??
            'Barang terawat dan siap COD di kampus. Silakan chat untuk info '
                'lebih lanjut atau tawar harga.',
        price: price,
        listingType: type,
        condition: cond,
        category: category,
        meetingPoint: point,
        sellerId: seller,
        createdAt: now.subtract(Duration(hours: ageHours)),
        expiresAt: now.add(Duration(days: 30, hours: -ageHours)),
        rentUnit: rentUnit,
        deposit: deposit,
        defectNote: defect,
        negotiable: nego,
        imageCount: urls.isNotEmpty ? urls.length : images,
        imageUrls: urls,
        status: status,
      );
    }

    return [
      mk(
        id: 'p1',
        title: 'Paket ESP32 WiFi + Bluetooth Starter Kit IoT',
        price: 145000,
        category: 'IoT',
        seller: 'u_dimas',
        urls: const [
          'https://images.unsplash.com/photo-1555664424-778a1e5e1b48?auto=format&fit=crop&w=800&q=80',
        ],
        defect: 'Kabel jumper kurang 3 buah.',
        desc:
            'Starter kit lengkap: ESP32 DevKit, breadboard, kabel jumper, '
            'LED, dan sensor suhu. Masih berfungsi normal, dipakai satu '
            'semester untuk tugas praktikum.',
        images: 4,
        ageHours: 3,
        status: ProductStatus.booked,
      ),
      mk(
        id: 'p2',
        title: 'Jas Lab Fakultas Teknik Ukuran L',
        price: 60000,
        category: 'Jas Lab',
        seller: 'u_anisa',
        urls: const [
          'https://images.unsplash.com/photo-1584556812952-905ffd0c611a?auto=format&fit=crop&w=800&q=80',
        ],
        defect: 'Ada noda kecil di lengan kiri.',
        point: 'Lobby Gedung',
        images: 2,
        ageHours: 8,
      ),
      mk(
        id: 'p3',
        title: 'Buku Struktur Data dan Algoritma (Baru)',
        price: 85000,
        category: 'Buku/Modul',
        seller: 'u_rian',
        urls: const [
          'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?auto=format&fit=crop&w=800&q=80',
        ],
        cond: ItemCondition.brandNew,
        images: 2,
        ageHours: 12,
        nego: false,
      ),
      mk(
        id: 'p4',
        title: 'Kalkulator Casio fx-991ID Plus',
        price: 195000,
        category: 'Alat Praktikum',
        seller: kMeId,
        urls: const [
          'https://images.unsplash.com/photo-1587145820266-a5951ee6f620?auto=format&fit=crop&w=800&q=80',
        ],
        defect: 'Tutup belakang agak longgar.',
        desc:
            'Kalkulator scientific, semua tombol normal dan layar jernih. '
            'Cocok untuk kuliah kalkulus dan fisika.',
        images: 3,
        ageHours: 20,
        point: 'Kantin',
      ),
      mk(
        id: 'p5',
        title: 'Laptop ASUS Vivobook 14 Ryzen 5',
        price: 4200000,
        category: 'Laptop & Aksesoris',
        seller: 'u_fajar',
        urls: const [
          'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?auto=format&fit=crop&w=800&q=80',
        ],
        defect: 'Baterai tahan sekitar 3 jam.',
        images: 5,
        ageHours: 30,
      ),
      mk(
        id: 'p6',
        title: 'Proyektor Mini Portable (Sewa)',
        price: 25000,
        category: 'Elektronik',
        seller: 'u_budi',
        urls: const [
          'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?auto=format&fit=crop&w=800&q=80',
        ],
        type: ListingType.rent,
        rentUnit: 'hari',
        deposit: 100000,
        defect: 'Remote tidak ada, kontrol lewat tombol di bodi.',
        images: 3,
        ageHours: 40,
        point: 'Taman Kampus',
      ),
      mk(
        id: 'p7',
        title: 'Modul Praktikum Basis Data',
        price: 15000,
        category: 'Buku/Modul',
        seller: 'u_nadia',
        urls: const [
          'https://images.unsplash.com/photo-1532012197267-da84d127e765?auto=format&fit=crop&w=800&q=80',
        ],
        defect: 'Beberapa halaman sudah dicoret pensil.',
        images: 1,
        ageHours: 50,
      ),
      mk(
        id: 'p8',
        title: 'Almamater Nusa Putra Ukuran M',
        price: 70000,
        category: 'Pakaian/Almamater',
        seller: kMeId,
        urls: const [
          'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=800&q=80',
        ],
        defect: 'Kancing paling atas diganti.',
        images: 2,
        ageHours: 60,
      ),
      mk(
        id: 'p9',
        title: 'Breadboard + Jumper + Resistor Set',
        price: 25000,
        category: 'IoT',
        seller: 'u_dimas',
        urls: const [
          'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=800&q=80',
        ],
        cond: ItemCondition.brandNew,
        images: 2,
        ageHours: 70,
        point: 'Perpustakaan',
      ),
      mk(
        id: 'p10',
        title: 'Mouse Wireless Logitech M185',
        price: 50000,
        category: 'Laptop & Aksesoris',
        seller: 'u_rian',
        urls: const [
          'https://images.unsplash.com/photo-1527864550417-7fd91fc51a46?auto=format&fit=crop&w=800&q=80',
        ],
        defect: 'Scroll kadang agak seret.',
        images: 2,
        ageHours: 90,
      ),
    ];
  }
}