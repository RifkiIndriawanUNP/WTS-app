import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wts/core/theme/app_theme.dart';
import 'package:wts/core/utils/format.dart';
import 'package:wts/core/utils/guard.dart';
import 'package:wts/features/market/domain/product.dart';
import 'package:wts/features/market/presentation/market_providers.dart';
import 'package:wts/shared/widgets/common_widgets.dart';
import 'package:wts/shared/widgets/glass.dart';

/// Formulir "Tambah Barang". Mengambil foto asli dari galeri lewat image_picker
/// (maksimal 10 foto) dan langsung menampilkannya.
class CreateProductPage extends ConsumerStatefulWidget {
  const CreateProductPage({super.key});

  @override
  ConsumerState<CreateProductPage> createState() => _CreateProductPageState();
}

class _CreateProductPageState extends ConsumerState<CreateProductPage> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _deposit = TextEditingController();
  final _defect = TextEditingController();

  ListingType _type = ListingType.sell;
  ItemCondition _condition = ItemCondition.used;
  String _category = kProductCategories.first;
  String _rentUnit = kRentUnits.first;
  String _meetingPoint = kMeetingPoints.first;
  bool _negotiable = true;
  bool _agreed = false;
  bool _saving = false;
  bool _submitted = false;

  final ImagePicker _picker = ImagePicker();
  final List<Uint8List> _selectedPhotos = [];

  int get _photos => _selectedPhotos.length;

  Future<void> _pickPhotos() async {
    if (_photos >= 10) {
      showSnack(context, 'Maksimal 10 foto.');
      return;
    }

    final remaining = 10 - _photos;
    try {
      final images = await _picker.pickMultiImage(
        imageQuality: 85,
        limit: remaining,
      );
      if (!mounted || images.isEmpty) return;

      final loaded = <Uint8List>[];
      for (final img in images.take(remaining)) {
        final bytes = await img.readAsBytes();
        if (bytes.isNotEmpty) {
          loaded.add(bytes);
        }
      }

      if (!mounted || loaded.isEmpty) return;
      setState(() {
        _selectedPhotos.addAll(loaded);
      });
    } catch (_) {
      if (!mounted) return;
      showSnack(context, 'Gagal membuka galeri foto.');
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    _deposit.dispose();
    _defect.dispose();
    super.dispose();
  }

  String? get _titleError {
    final t = _title.text.trim();
    if (t.isEmpty) return 'Nama barang wajib diisi';
    if (t.length > 100) return 'Maksimal 100 karakter';
    return null;
  }

  String? get _descError {
    final t = _desc.text.trim();
    if (t.isEmpty) return 'Deskripsi wajib diisi';
    if (t.length > 2000) return 'Maksimal 2000 karakter';
    return null;
  }

  String? get _priceError {
    final v = parseRupiah(_price.text);
    if (v == null || v <= 0) return 'Harga wajib diisi';
    if (v > 100000000) return 'Maksimal Rp100.000.000';
    return null;
  }

  String? get _defectError {
    if (_condition == ItemCondition.used && _defect.text.trim().isEmpty) {
      return 'Kekurangan barang second wajib diisi';
    }
    return null;
  }

  bool get _valid =>
      _titleError == null &&
      _descError == null &&
      _priceError == null &&
      _defectError == null &&
      _photos >= 1 &&
      _agreed;

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!_valid) {
      showSnack(context, 'Lengkapi data yang masih kosong.');
      return;
    }
    setState(() => _saving = true);
    final created = await guarded(context, () {
      return ref
          .read(marketRepositoryProvider)
          .createProduct(
            NewProductInput(
              title: _title.text.trim(),
              description: _desc.text.trim(),
              price: parseRupiah(_price.text)!,
              listingType: _type,
              condition: _condition,
              category: _category,
              meetingPoint: _meetingPoint,
              imageCount: _photos,
              photoBytesList: List<Uint8List>.from(_selectedPhotos),
              rentUnit: _type == ListingType.rent ? _rentUnit : null,
              deposit: _type == ListingType.rent
                  ? parseRupiah(_deposit.text)
                  : null,
              defectNote: _condition == ItemCondition.used
                  ? _defect.text.trim()
                  : null,
              negotiable: _negotiable,
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

  @override
  Widget build(BuildContext context) {
    final isRent = _type == ListingType.rent;
    return GlassScaffold(
      body: SafeArea(
        child: Column(
          children: [
            GlassHeader(title: 'Tambah Barang', onBack: context.pop),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _label('Foto barang (maks. 10)'),
                  SizedBox(
                    height: 84,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (var i = 0; i < _photos; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: SizedBox(
                                    width: 84,
                                    height: 84,
                                    child: Image.memory(
                                      _selectedPhotos[i],
                                      width: 84,
                                      height: 84,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 2,
                                  top: 2,
                                  child: GestureDetector(
                                    onTap: () => _removePhoto(i),
                                    child: const CircleAvatar(
                                      radius: 10,
                                      backgroundColor: Colors.black54,
                                      child: Icon(
                                        Icons.close,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_photos < 10)
                          GestureDetector(
                            onTap: _pickPhotos,
                            child: Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .7),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 1.4,
                                ),
                              ),
                              child: const Icon(
                                Icons.add_photo_alternate_outlined,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_submitted && _photos < 1)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Minimal 1 foto',
                        style: TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    ),
                  _label('Pilih jenis penawaran'),
                  Row(
                    children: [
                      Expanded(
                        child: _segment(
                          'Jual',
                          !isRent,
                          () => setState(() => _type = ListingType.sell),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _segment(
                          'Sewa',
                          isRent,
                          () => setState(() => _type = ListingType.rent),
                        ),
                      ),
                    ],
                  ),
                  _label('Nama barang'),
                  TextField(
                    controller: _title,
                    maxLength: 100,
                    onChanged: (_) => setState(() {}),
                    decoration: glassInput(
                      hint: 'mis. Proyektor Mini Portable',
                      errorText: _submitted ? _titleError : null,
                    ),
                  ),
                  _label('Kategori'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in kProductCategories)
                        GlassChip(
                          label: c,
                          selected: _category == c,
                          onTap: () => setState(() => _category = c),
                        ),
                    ],
                  ),
                  _label('Kondisi'),
                  Row(
                    children: [
                      Expanded(
                        child: _segment(
                          'Bekas',
                          _condition == ItemCondition.used,
                          () => setState(() => _condition = ItemCondition.used),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _segment(
                          'Baru',
                          _condition == ItemCondition.brandNew,
                          () => setState(
                            () => _condition = ItemCondition.brandNew,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_condition == ItemCondition.used) ...[
                    _label('Kekurangan barang'),
                    TextField(
                      controller: _defect,
                      maxLines: 2,
                      onChanged: (_) => setState(() {}),
                      decoration: glassInput(
                        hint: 'mis. Baterai tahan 3 jam',
                        errorText: _submitted ? _defectError : null,
                      ),
                    ),
                  ],
                  _label(isRent ? 'Harga sewa' : 'Harga jual'),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _price,
                          keyboardType: TextInputType.number,
                          inputFormatters: [RupiahInputFormatter()],
                          onChanged: (_) => setState(() {}),
                          decoration: glassInput(
                            hint: '0',
                            prefixText: 'Rp ',
                            errorText: _submitted ? _priceError : null,
                          ),
                        ),
                      ),
                      if (isRent) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: _rentUnit,
                            decoration: glassInput(),
                            items: [
                              for (final u in kRentUnits)
                                DropdownMenuItem(value: u, child: Text('/ $u')),
                            ],
                            onChanged: (v) =>
                                setState(() => _rentUnit = v ?? _rentUnit),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (isRent) ...[
                    _label('Deposit (opsional)'),
                    TextField(
                      controller: _deposit,
                      keyboardType: TextInputType.number,
                      inputFormatters: [RupiahInputFormatter()],
                      decoration: glassInput(hint: '0', prefixText: 'Rp '),
                    ),
                  ],
                  _label('Deskripsi'),
                  TextField(
                    controller: _desc,
                    maxLines: 4,
                    maxLength: 2000,
                    onChanged: (_) => setState(() {}),
                    decoration: glassInput(
                      hint: 'Ceritakan kondisi, kelengkapan, dsb.',
                      errorText: _submitted ? _descError : null,
                    ),
                  ),
                  _label('Titik temu COD'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in kMeetingPoints)
                        GlassChip(
                          label: m,
                          selected: _meetingPoint == m,
                          icon: Icons.place_outlined,
                          onTap: () => setState(() => _meetingPoint = m),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Harga bisa nego'),
                    value: _negotiable,
                    onChanged: (v) => setState(() => _negotiable = v),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _agreed,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                    title: const Text(
                      'Saya tidak menjual barang terlarang (narkoba, miras, '
                      'rokok/vape, senjata, obat resep, soal ujian/joki, '
                      'barang curian/bajakan, konten dewasa).',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                  if (_submitted && !_agreed)
                    const Text(
                      'Centang pernyataan di atas untuk melanjutkan.',
                      style: TextStyle(color: AppColors.danger, fontSize: 12),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: const StadiumBorder(),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Posting Barang'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
    ),
  );

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : Colors.white.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(23),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}