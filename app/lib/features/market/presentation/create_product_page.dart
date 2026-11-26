
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wts/core/utils/format.dart';
import 'package:wts/core/utils/guard.dart';
import 'package:wts/features/market/domain/product.dart';
import 'package:wts/features/market/presentation/market_providers.dart';
import 'package:wts/features/market/presentation/market_style.dart';
import 'package:wts/shared/widgets/app_icons.dart';

const int _kMaxPhotos = 5;
const double _kTile = 95;

/// Kategori yang langsung terlihat di form (sisanya lewat tombol "+").
const _kVisibleCategories = <String>['IoT', 'Elektronik', 'Buku', 'Kos'];

/// Form "Posting Barang": langkah 1 (foto, jenis, nama, kategori, kondisi)
/// lalu langkah 2 (harga, penawaran, serah terima, deskripsi).
class CreateProductPage extends ConsumerStatefulWidget {
  const CreateProductPage({super.key});

  @override
  ConsumerState<CreateProductPage> createState() => _CreateProductPageState();
}

class _CreateProductPageState extends ConsumerState<CreateProductPage> {
  final _title = TextEditingController();
  final _defect = TextEditingController();
  final _price = TextEditingController();
  final _desc = TextEditingController();

  int _step = 0;
  ListingType _type = ListingType.sell;
  ItemCondition _condition = ItemCondition.used;
  bool _hasDefect = true;
  String _category = 'Elektronik';
  String _rentUnit = kRentUnits.first;
  bool _negotiable = true;
  Handover _handover = Handover.codKampus;
  bool _saving = false;

  final ImagePicker _picker = ImagePicker();
  final List<Uint8List> _photos = [];

  @override
  void dispose() {
    _title.dispose();
    _defect.dispose();
    _price.dispose();
    _desc.dispose();
    super.dispose();
  }

  bool get _isFree => _type == ListingType.free;
  bool get _isRent => _type == ListingType.rent;

  Future<void> _pickPhotos() async {
    final remaining = _kMaxPhotos - _photos.length;
    if (remaining <= 0) {
      showSnack(context, 'Maksimal $_kMaxPhotos foto.');
      return;
    }
    try {
      final files = <XFile>[];
      if (remaining == 1) {
        final one = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        if (one != null) files.add(one);
      } else {
        files.addAll(
          await _picker.pickMultiImage(imageQuality: 85, limit: remaining),
        );
      }
      if (!mounted || files.isEmpty) return;
      final loaded = <Uint8List>[];
      for (final f in files.take(remaining)) {
        final bytes = await f.readAsBytes();
        if (bytes.isNotEmpty) loaded.add(bytes);
      }
      if (!mounted || loaded.isEmpty) return;
      setState(() => _photos.addAll(loaded));
    } catch (_) {
      if (mounted) showSnack(context, 'Gagal membuka galeri foto.');
    }
  }

  void _setType(ListingType t) {
    setState(() {
      _type = t;
      if (t == ListingType.free) {
        _negotiable = false;
        _price.clear();
      }
    });
  }

  void _next() {
    if (_photos.isEmpty) {
      showSnack(context, 'Tambahkan minimal 1 foto barang.');
      return;
    }
    if (_title.text.trim().isEmpty) {
      showSnack(context, 'Nama barang wajib diisi.');
      return;
    }
    if (_hasDefect && _defect.text.trim().isEmpty) {
      showSnack(context, 'Isi minus barang, atau pilih "Tidak ada".');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _step = 1);
  }

  Future<void> _submit() async {
    final price = _isFree ? 0 : parseRupiah(_price.text);
    if (!_isFree && (price == null || price <= 0)) {
      showSnack(context, 'Harga wajib diisi.');
      return;
    }
    if (price != null && price > 100000000) {
      showSnack(context, 'Maksimal Rp100.000.000.');
      return;
    }
    if (_desc.text.trim().isEmpty) {
      showSnack(context, 'Deskripsi wajib diisi.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final created = await guarded(context, () {
      return ref.read(marketRepositoryProvider).createProduct(
            NewProductInput(
              title: _title.text.trim(),
              description: _desc.text.trim(),
              price: price ?? 0,
              listingType: _type,
              condition: _condition,
              category: _category,
              meetingPoint: kMeetingPoints.first,
              imageCount: _photos.length,
              photoBytesList: List<Uint8List>.from(_photos),
              rentUnit: _isRent ? _rentUnit : null,
              defectNote: _hasDefect ? _defect.text.trim() : null,
              negotiable: _isFree ? false : _negotiable,
              handover: _handover,
            ),
          );
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (created != null) {
      context.pop();
      showSnack(context, 'Barang berhasil diposting.');
    }
  }

  Future<void> _openCategorySheet() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih kategori',
                style: mt(size: 18, weight: FontWeight.w800, color: MC.ink),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in kProductCategories)
                    ChoicePill(
                      label: c,
                      selected: _category == c,
                      filled: true,
                      height: 40,
                      horizontal: 20,
                      onTap: () => Navigator.of(ctx).pop(c),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _category = picked);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step = 0);
      },
      child: Scaffold(
        backgroundColor: MC.bg,
        body: SafeArea(
          child: Column(
            children: [
              MarketTitleBar(
                title: 'Posting Barang',
                onBack: () {
                  if (_step == 1) {
                    setState(() => _step = 0);
                  } else {
                    context.pop();
                  }
                },
              ),
              Expanded(child: _step == 0 ? _stepOne() : _stepTwo()),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- Langkah 1

  Widget _stepOne() {
    final extra = _kVisibleCategories.contains(_category) ? null : _category;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
            children: [
              _label('Foto barang (maks. $_kMaxPhotos)'),
              SizedBox(
                height: _kTile,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var i = 0; i < _photos.length; i++) _photoTile(i),
                    if (_photos.isEmpty) const _EmptyCover(),
                    if (_photos.length < _kMaxPhotos)
                      for (var i = 0; i < (_photos.isEmpty ? 2 : 1); i++)
                        _AddTile(onTap: _pickPhotos),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _label('Pilih jenis penawaran'),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  for (final t in ListingType.values)
                    ChoicePill(
                      label: t.label,
                      selected: _type == t,
                      filled: true,
                      shadow: true,
                      height: 40,
                      horizontal: 22,
                      fontSize: 13,
                      onTap: () => _setType(t),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _label('Nama barang'),
              _input(_title, hint: 'Nama barang', maxLength: 100),
              const SizedBox(height: 16),
              _label('Kategori'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in [..._kVisibleCategories, ?extra])
                    ChoicePill(
                      label: c,
                      selected: _category == c,
                      filled: true,
                      shadow: true,
                      height: 40,
                      horizontal: 22,
                      fontSize: 13,
                      onTap: () => setState(() => _category = c),
                    ),
                  GestureDetector(
                    onTap: _openCategorySheet,
                    child: Container(
                      width: 56,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: softShadow(.05, 10),
                      ),
                      child: const AppIcon(WtsIcons.plus, size: 20, color: MC.text),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _label('Kondisi'),
              PillSegmented(
                labels: const ['Baru', 'Second'],
                index: _condition == ItemCondition.brandNew ? 0 : 1,
                onChanged: (i) => setState(
                  () => _condition =
                      i == 0 ? ItemCondition.brandNew : ItemCondition.used,
                ),
              ),
              const SizedBox(height: 16),
              _label('Ada minus ?'),
              PillSegmented(
                labels: const ['Tidak ada', 'Ada'],
                index: _hasDefect ? 1 : 0,
                onChanged: (i) => setState(() => _hasDefect = i == 1),
              ),
              if (_hasDefect) ...[
                const SizedBox(height: 14),
                _label('Minus apa saja?'),
                _input(
                  _defect,
                  hint: 'Contoh: lecet di sudut kiri atas',
                  maxLines: 2,
                  minLines: 2,
                  maxLength: 300,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 8, 0, 0),
                  child: Text(
                    'Foto bagian yang minus akan tampil di halaman barang.',
                    style: mt(size: 12, weight: FontWeight.w500, color: MC.slate),
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 6, 30, 14),
          child: GradientButton(
            label: 'Lanjut',
            height: 48,
            fontSize: 18,
            glow: true,
            onTap: _next,
          ),
        ),
      ],
    );
  }

  Widget _photoTile(int i) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: _kTile,
              height: _kTile,
              child: Image.memory(
                _photos[i],
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const PeachPlaceholder(),
              ),
            ),
          ),
          Positioned(
            right: 5,
            top: 5,
            child: GestureDetector(
              onTap: () => setState(() => _photos.removeAt(i)),
              child: const CircleAvatar(
                radius: 11,
                backgroundColor: Colors.black54,
                child: AppIcon(WtsIcons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Langkah 2

  Widget _stepTwo() {
    final priceLabel = _isRent ? 'Harga sewa' : (_isFree ? 'Harga' : 'Harga jual');
    final priceValue = parseRupiah(_price.text);
    final helper = _isFree
        ? 'Tampil sebagai "Rp 0" secara default'
        : (_isRent
            ? 'Tampil sebagai "${rp(priceValue ?? 0)} / $_rentUnit"'
            : null);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
      children: [
        _label(priceLabel),
        Row(
          children: [
            Expanded(
              child: _input(
                _price,
                hint: 'Rp 0',
                enabled: !_isFree,
                prefix: _isFree ? null : 'Rp ',
                keyboard: TextInputType.number,
                formatters: [RupiahInputFormatter()],
                onChanged: (_) => setState(() {}),
                bold: true,
              ),
            ),
            if (_isRent) ...[
              const SizedBox(width: 14),
              _UnitDropdown(
                value: _rentUnit,
                onChanged: (v) => setState(() => _rentUnit = v),
              ),
            ],
          ],
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 0, 0),
            child: Text(
              helper,
              style: mt(size: 12.5, weight: FontWeight.w500, color: MC.slate),
            ),
          ),
        const SizedBox(height: 16),
        _label('Pilih jenis penawaran'),
        IgnorePointer(
          ignoring: _isFree,
          child: PillSegmented(
            labels: const ['Bisa nego', 'Harga pas'],
            index: _negotiable ? 0 : 1,
            onChanged: (i) => setState(() => _negotiable = i == 0),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 0, 0),
          child: Text(
            'Harga pas: Pembeli tidak bisa menawar. Mereka tetap mengajukan waktu, dan tempat',
            style: mt(
              size: 12.5,
              weight: FontWeight.w500,
              color: MC.slate,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _label('Serah terima'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final h in Handover.values)
              _HandoverChip(
                label: h.label,
                selected: _handover == h,
                onTap: () => setState(() => _handover = h),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _label('Deskripsi'),
        _input(
          _desc,
          hint: 'Ukuran, bahan, alasan jual...',
          minLines: 4,
          maxLines: 6,
          maxLength: 2000,
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: GradientButton(
            label: 'Posting barang',
            height: 48,
            fontSize: 18,
            glow: true,
            loading: _saving,
            onTap: _submit,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- Bantuan

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        text,
        style: mt(size: 15, weight: FontWeight.w800, color: MC.ink),
      ),
    );
  }

  Widget _input(
    TextEditingController c, {
    String? hint,
    String? prefix,
    int minLines = 1,
    int maxLines = 1,
    int? maxLength,
    bool enabled = true,
    bool bold = false,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    ValueChanged<String>? onChanged,
  }) {
    final multi = maxLines > 1;
    return TextField(
      controller: c,
      enabled: enabled,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboard ?? (multi ? TextInputType.multiline : null),
      inputFormatters: [...?formatters, ?(maxLength == null ? null : LengthLimitingTextInputFormatter(maxLength))],
      onChanged: onChanged,
      style: mt(
        size: 15.5,
        weight: bold ? FontWeight.w700 : FontWeight.w500,
        color: MC.ink,
        height: multi ? 1.4 : null,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        counterText: '',
        hintText: hint,
        hintStyle: mt(size: 15, weight: FontWeight.w500, color: MC.slateLight),
        prefixText: prefix,
        prefixStyle: mt(size: 15.5, weight: FontWeight.w700, color: MC.ink),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 18,
          vertical: multi ? 14 : 16,
        ),
        border: _border(MC.line),
        enabledBorder: _border(MC.line),
        disabledBorder: _border(MC.line),
        focusedBorder: _border(MC.blue, width: 1.4),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// Slot foto pertama yang masih kosong (peach + ikon gambar oranye).
class _EmptyCover extends StatelessWidget {
  const _EmptyCover();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Container(
        width: _kTile,
        height: _kTile,
        decoration: BoxDecoration(
          color: MC.peach,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const AppIcon(WtsIcons.image, size: 24, color: MC.orangeDeep),
      ),
    );
  }
}

/// Slot "+ Tambah" dengan tepi putus-putus biru.
class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedRRect(color: const Color(0xFF60A5FA), radius: 16),
          child: SizedBox(
            width: _kTile,
            height: _kTile,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppIcon(WtsIcons.plus, size: 30, color: MC.blue),
                Text(
                  'Tambah',
                  style: mt(size: 12, weight: FontWeight.w700, color: MC.blue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRect extends CustomPainter {
  _DashedRRect({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(.8),
      );
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRect old) =>
      old.color != color || old.radius != radius;
}

class _UnitDropdown extends StatelessWidget {
  const _UnitDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (_) => [
        for (final u in kRentUnits)
          PopupMenuItem(
            value: u,
            child: Text('/ $u', style: mt(size: 14, weight: FontWeight.w600)),
          ),
      ],
      child: Container(
        width: 104,
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MC.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '/ $value',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mt(size: 15, weight: FontWeight.w700, color: MC.ink),
              ),
            ),
            const AppIcon(WtsIcons.chevronDown, size: 20, color: MC.slate),
          ],
        ),
      ),
    );
  }
}

class _HandoverChip extends StatelessWidget {
  const _HandoverChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFFF3F5F9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? MC.line : Colors.transparent),
          boxShadow: selected ? softShadow(.05, 10) : null,
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: mt(
              size: 15,
              weight: FontWeight.w800,
              color: selected ? MC.text : MC.slateLight,
            ),
          ),
        ),
      ),
    );
  }
}