import 'package:flutter/material.dart';
import 'package:wts/features/market/domain/product.dart';
import 'package:wts/features/market/presentation/market_style.dart';
import 'package:wts/shared/models/app_user.dart';
import 'package:wts/shared/widgets/app_icons.dart';

/// Hasil sheet "Ajukan kesepakatan".
class OfferDraft {
  const OfferDraft({
    required this.price,
    required this.when,
    required this.place,
  });

  final int price;
  final DateTime when;
  final String place;
}

const kOfferPlaces = <String>[
  'Kantin',
  'Depan Pintu Alfa',
  'Loby Gedung A',
  'Tempat Tunggu Apotek Gedung B',
  'Perpustakaan Gedung B',
];

const _kPriceStep = 5000;
const _kOpenHour = 7;
const _kCloseHour = 17;

Future<OfferDraft?> showOfferSheet(BuildContext context, Product product) {
  return showModalBottomSheet<OfferDraft>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OfferSheet(product: product),
  );
}

class _OfferSheet extends StatefulWidget {
  const _OfferSheet({required this.product});

  final Product product;

  @override
  State<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<_OfferSheet> {
  late int _price;
  late DateTime _date;
  late TimeOfDay _time;
  String _place = kOfferPlaces.first;

  Product get _p => widget.product;

  /// Harga pas: pembeli tidak bisa menawar, hanya mengajukan waktu & tempat.
  bool get _fixedPrice => !_p.negotiable;

  @override
  void initState() {
    super.initState();
    final base = _p.price;
    _price = _fixedPrice
        ? base
        : (base > _kPriceStep * 3 ? base - 2 * _kPriceStep : base);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _date = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    _time = const TimeOfDay(hour: 10, minute: 0);
  }

  void _step(int delta) {
    if (_fixedPrice) return;
    setState(() => _price = (_price + delta).clamp(1000, 100000000));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 7)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t == null) return;
    if (t.hour < _kOpenHour || t.hour > _kCloseHour ||
        (t.hour == _kCloseHour && t.minute > 0)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Jam temu hanya 07.00 – 17.00.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    setState(() => _time = t);
  }

  void _submit() {
    Navigator.of(context, rootNavigator: true).pop(
      OfferDraft(
        price: _price,
        when: DateTime(
          _date.year,
          _date.month,
          _date.day,
          _time.hour,
          _time.minute,
        ),
        place: _place,
      ),
    );
  }

  String _dateText(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

  String _timeText(TimeOfDay t) {
    final h12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '${h12.toString().padLeft(2, '0')}:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final seller = userById(_p.sellerId);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * .95;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ajukan kesepakatan',
                    style: mt(size: 22, weight: FontWeight.w800, color: MC.ink),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${seller.name} · harga barang ${rp(_p.price)}',
                    style: mt(
                      size: 15,
                      weight: FontWeight.w500,
                      color: MC.slate,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _heading('1', 'Harga'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _StepButton(
                        icon: WtsIcons.minus,
                        onTap: _fixedPrice ? null : () => _step(-_kPriceStep),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              _fixedPrice ? 'Harga pas' : 'Tawaranmu',
                              style: mt(
                                size: 13,
                                weight: FontWeight.w500,
                                color: MC.slate,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              rp(_price),
                              style: mt(
                                size: 34,
                                weight: FontWeight.w800,
                                color: MC.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _StepButton(
                        icon: WtsIcons.plus,
                        onTap: _fixedPrice ? null : () => _step(_kPriceStep),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _heading('2', 'Waktu', hint: 'maksimal 7 hari ke depan'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          label: 'Tanggal',
                          value: _dateText(_date),
                          leading: WtsIcons.calendar,
                          onTap: _pickDate,
                          alignStart: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Field(
                          label: 'Jam',
                          value: _timeText(_time),
                          onTap: _pickTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      'Maks. 7 hari ke depan • 07.00 – 17.00',
                      style: mt(
                        size: 12,
                        weight: FontWeight.w500,
                        color: MC.slate,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _heading('3', 'Tempat', hint: 'titik ramai di kampus'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final place in kOfferPlaces)
                        ChoicePill(
                          label: place,
                          selected: _place == place,
                          height: 44,
                          horizontal: 20,
                          fontSize: 14,
                          onTap: () => setState(() => _place = place),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MC.blueInfo,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: AppIcon(
                            WtsIcons.info,
                            size: 20,
                            color: MC.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Pembayaran langsung di tempat (COD), periksa barang dulu. Penjual punya 24 jam untuk menjawab, dan kamu bisa membatalkan sebelum dijawab.',
                            style: mt(
                              size: 14,
                              weight: FontWeight.w500,
                              color: MC.blue,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 14 + bottom),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlineBlueButton(
                    label: 'Batal',
                    height: 50,
                    fontSize: 15,
                    onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: GradientButton(
                    label: 'Kirim ke penjual',
                    height: 50,
                    fontSize: 15,
                    onTap: _submit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heading(String n, String title, {String? hint}) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$n · $title',
            style: mt(size: 18, weight: FontWeight.w800, color: MC.ink),
          ),
          if (hint != null)
            TextSpan(
              text: '  $hint',
              style: mt(size: 14, weight: FontWeight.w500, color: MC.slate),
            ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final WtsIcon icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? .4 : 1,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD5DCE8)),
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: AppIcon(icon, size: 24, color: MC.text),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.onTap,
    this.leading,
    this.alignStart = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final WtsIcon? leading;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: mt(size: 12, weight: FontWeight.w500, color: MC.slate),
          ),
        ),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFD5DCE8)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: alignStart
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  if (leading != null) ...[
                    AppIcon(leading, size: 22, color: MC.text),
                    const SizedBox(width: 12),
                  ],
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mt(
                        size: 15,
                        weight: FontWeight.w600,
                        color: MC.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}