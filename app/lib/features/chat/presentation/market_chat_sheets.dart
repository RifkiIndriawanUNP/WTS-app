import 'package:flutter/material.dart';
import 'package:wts/core/utils/guard.dart';
import 'package:wts/features/chat/presentation/chat_ui.dart';
import 'package:wts/features/market/domain/product.dart';

// ---------------------------------------------------------- tolak tawaran

const kRejectReasons = <String>[
  'Harga terlalu rendah',
  'Barang sudah ada yang pegang',
  'Saya batal menjual',
];

/// Sheet "Tolak kesepakatan ini?" -> alasan terpilih, atau null bila batal.
Future<String?> showRejectSheet(
  BuildContext context, {
  required String peerName,
}) {
  return showChatSheet<String>(
    context,
    builder: (_) => _RejectSheet(peerName: peerName),
  );
}

class _RejectSheet extends StatefulWidget {
  const _RejectSheet({required this.peerName});

  final String peerName;

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return ChatSheetFrame(
      title: 'Tolak kesepakatan ini?',
      subtitle:
          'Pilih alasan agar ${widget.peerName} tahu. Chat tetap terbuka untuk diskusi lagi.',
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (var i = 0; i < kRejectReasons.length; i++)
              InkWell(
                onTap: () => setState(() => _selected = i),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      _Radio(selected: i == _selected),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          kRejectReasons[i],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: ChatColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _OutlinePill(
                    label: 'Batal',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 8,
                  child: ChatButton(
                    label: 'Tolak tawaran',
                    filled: true,
                    color: const Color(0xFFE5484D),
                    height: 54,
                    onTap: () =>
                        Navigator.of(context).pop(kRejectReasons[_selected]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? ChatColors.blue : const Color(0xFFC9D0DE),
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 13,
              height: 13,
              decoration: const BoxDecoration(
                color: ChatColors.blue,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

class _OutlinePill extends StatelessWidget {
  const _OutlinePill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(
        side: BorderSide(color: Color(0xFFD5DAE5), width: 1.5),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 54,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: ChatColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- tempat & waktu

/// Pilih tanggal (maks. 7 hari ke depan) lalu jam. Null bila batal.
Future<DateTime?> pickMeetTime(BuildContext context, DateTime current) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final initial = current.isBefore(today) ? today : current;
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: today,
    lastDate: today.add(const Duration(days: 7)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(current),
  );
  if (time == null || !context.mounted) return null;
  final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  if (picked.isBefore(now)) {
    showSnack(context, 'Waktu pertemuan sudah lewat');
    return null;
  }
  return picked;
}

/// Pilih titik temu dari daftar titik kampus. Null bila batal.
Future<String?> showPlaceSheet(BuildContext context, {String? current}) {
  return showChatSheet<String>(
    context,
    builder: (ctx) => ChatSheetFrame(
      title: 'Pilih titik temu',
      subtitle: 'Pilih titik yang ramai dan mudah ditemukan.',
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (final p in kMeetingPoints)
              InkWell(
                onTap: () => Navigator.of(ctx).pop(p),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      _Radio(selected: p == current),
                      const SizedBox(width: 14),
                      Text(
                        p,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ChatColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

// ------------------------------------------------------- ubah kesepakatan

typedef OfferDraft = ({int price, DateTime meetAt, String place});

/// Sheet "Ubah kesepakatan": harga, waktu, tempat. [step] negatif bila saya
/// pembeli (menawar turun), positif bila penjual.
Future<OfferDraft?> showEditOfferSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String baseLabel,
  required int basePrice,
  required int step,
  required DateTime initialMeetAt,
  required String initialPlace,
  required String warning,
  String ctaLabel = 'Kirim kesepakatan baru',
}) {
  return showChatSheet<OfferDraft>(
    context,
    builder: (_) => _EditOfferSheet(
      title: title,
      subtitle: subtitle,
      baseLabel: baseLabel,
      basePrice: basePrice,
      step: step,
      initialMeetAt: initialMeetAt,
      initialPlace: initialPlace,
      warning: warning,
      ctaLabel: ctaLabel,
    ),
  );
}

class _EditOfferSheet extends StatefulWidget {
  const _EditOfferSheet({
    required this.title,
    required this.subtitle,
    required this.baseLabel,
    required this.basePrice,
    required this.step,
    required this.initialMeetAt,
    required this.initialPlace,
    required this.warning,
    required this.ctaLabel,
  });

  final String title;
  final String subtitle;
  final String baseLabel;
  final int basePrice;
  final int step;
  final DateTime initialMeetAt;
  final String initialPlace;
  final String warning;
  final String ctaLabel;

  @override
  State<_EditOfferSheet> createState() => _EditOfferSheetState();
}

class _EditOfferSheetState extends State<_EditOfferSheet> {
  static const _unit = 5000;
  static const _maxPrice = 100000000;

  late int _price;
  late DateTime _meetAt;
  late String _place;

  @override
  void initState() {
    super.initState();
    _price = (widget.basePrice + widget.step).clamp(1000, _maxPrice);
    _meetAt = widget.initialMeetAt;
    _place = widget.initialPlace;
  }

  void _bump(int delta) =>
      setState(() => _price = (_price + delta).clamp(1000, _maxPrice));

  List<int> get _chips {
    final list = <int>{
      widget.basePrice,
      widget.basePrice + widget.step,
      widget.basePrice + widget.step * 2,
    }.where((v) => v >= 1000 && v <= _maxPrice).toList()
      ..sort();
    return list;
  }

  Future<void> _editTime() async {
    final picked = await pickMeetTime(context, _meetAt);
    if (picked != null && mounted) setState(() => _meetAt = picked);
  }

  Future<void> _editPlace() async {
    final picked = await showPlaceSheet(context, current: _place);
    if (picked != null && mounted) setState(() => _place = picked);
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: ChatColors.ink,
          ),
        ),
      );

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD5DAE5), width: 1.5),
        ),
        child: Icon(icon, size: 24, color: ChatColors.ink),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String sub,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E7F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: ChatColors.blueTint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: ChatColors.blue, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: ChatColors.ink,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: ChatColors.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: const Text(
              'Ubah',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: ChatColors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChatSheetFrame(
      title: widget.title,
      subtitle: widget.subtitle,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('1 · Harga'),
            Center(
              child: Text(
                widget.baseLabel,
                style: const TextStyle(fontSize: 12.5, color: ChatColors.muted),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _stepButton(Icons.remove_rounded, () => _bump(-_unit)),
                Text(
                  chatRp(_price),
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: ChatColors.ink,
                  ),
                ),
                _stepButton(Icons.add_rounded, () => _bump(_unit)),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final v in _chips)
                  GestureDetector(
                    onTap: () => setState(() => _price = v),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: v == _price
                              ? ChatColors.blue
                              : const Color(0xFFD5DAE5),
                          width: v == _price ? 2 : 1.2,
                        ),
                      ),
                      child: Text(
                        chatRp(v),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              v == _price ? FontWeight.w800 : FontWeight.w600,
                          color: v == _price ? ChatColors.blue : ChatColors.ink,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            _section('2 · Waktu'),
            _infoRow(
              icon: Icons.calendar_month_outlined,
              title: '${dayLong(_meetAt)} · ${dotClock(_meetAt)}',
              sub:
                  '${daysUntilLabel(_meetAt).toLowerCase()}, maksimal 7 hari ke depan',
              onTap: _editTime,
            ),
            _section('3 · Tempat'),
            _infoRow(
              icon: Icons.location_on_outlined,
              title: _place,
              sub: 'Pilih titik yang ramai dan mudah ditemukan',
              onTap: _editPlace,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF6E7B8)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 22,
                    color: Color(0xFFB45309),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.warning,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF92400E),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ChatButton(
              label: widget.ctaLabel,
              filled: true,
              height: 56,
              onTap: () => Navigator.of(context).pop(
                (price: _price, meetAt: _meetAt, place: _place),
              ),
            ),
          ],
        ),
      ),
    );
  }
}