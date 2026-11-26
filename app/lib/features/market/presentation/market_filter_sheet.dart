import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wts/core/utils/format.dart';
import 'package:wts/features/market/domain/product.dart';
import 'package:wts/features/market/presentation/market_providers.dart';
import 'package:wts/features/market/presentation/market_style.dart';

typedef MarketFilterProvider
    = NotifierProvider<MarketFilterNotifier, MarketFilter>;

/// Bottom sheet "Filter". [provider] menentukan filter mana yang diubah
/// (beranda: [marketFilterProvider], pencarian: [searchFilterProvider]).
Future<void> showMarketFilterSheet(
  BuildContext context,
  MarketFilterProvider provider,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MarketFilterSheet(provider: provider),
  );
}

class MarketFilterSheet extends ConsumerStatefulWidget {
  const MarketFilterSheet({super.key, required this.provider});

  final MarketFilterProvider provider;

  @override
  ConsumerState<MarketFilterSheet> createState() => _MarketFilterSheetState();
}

class _MarketFilterSheetState extends ConsumerState<MarketFilterSheet> {
  late MarketFilter _draft;
  late final TextEditingController _min;
  late final TextEditingController _max;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(widget.provider);
    _min = TextEditingController(
      text: _draft.minPrice == null ? '' : formatThousands(_draft.minPrice!),
    );
    _max = TextEditingController(
      text: _draft.maxPrice == null ? '' : formatThousands(_draft.maxPrice!),
    );
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _apply() {
    ref.read(widget.provider.notifier).replace(
          _draft.copyWith(
            minPrice: parseRupiah(_min.text),
            maxPrice: parseRupiah(_max.text),
          ),
        );
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _reset() {
    setState(() {
      _draft = MarketFilter(query: _draft.query, sort: _draft.sort);
      _min.clear();
      _max.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * .92;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: EdgeInsets.only(bottom: keyboard),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
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
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'Filter',
                      style: mt(
                        size: 20,
                        weight: FontWeight.w800,
                        color: MC.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    'Jenis',
                    _wrap([
                      _pill('Semua', _draft.type == null,
                          () => setState(() => _draft = _draft.copyWith(type: null))),
                      for (final t in ListingType.values)
                        _pill(t.label, _draft.type == t,
                            () => setState(() => _draft = _draft.copyWith(type: t))),
                    ]),
                  ),
                  _Section(
                    'Kategori',
                    _wrap([
                      _pill('Semua', _draft.category == null,
                          () => setState(() => _draft = _draft.copyWith(category: null))),
                      for (final c in kProductCategories)
                        _pill(c, _draft.category == c,
                            () => setState(() => _draft = _draft.copyWith(category: c))),
                    ]),
                  ),
                  _Section(
                    'Kondisi',
                    _wrap([
                      _pill('Semua', _draft.condition == null,
                          () => setState(() => _draft = _draft.copyWith(condition: null))),
                      _pill('Baru', _draft.condition == ItemCondition.brandNew,
                          () => setState(() => _draft = _draft.copyWith(condition: ItemCondition.brandNew))),
                      _pill('Second', _draft.condition == ItemCondition.used,
                          () => setState(() => _draft = _draft.copyWith(condition: ItemCondition.used))),
                    ]),
                  ),
                  _Section(
                    'Harga',
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: _priceField('Minimum', _min, 'Rp 0')),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: SizedBox(
                            width: 32,
                            child: Center(
                              child: Text(
                                '–',
                                style: mt(size: 16, color: MC.slate),
                              ),
                            ),
                          ),
                        ),
                        Expanded(child: _priceField('Maksimum', _max, 'Tanpa batas')),
                      ],
                    ),
                  ),
                  _Section(
                    'Penawaran',
                    _wrap([
                      _pill('Semua', _draft.negotiable == null,
                          () => setState(() => _draft = _draft.copyWith(negotiable: null))),
                      _pill('Bisa nego', _draft.negotiable == true,
                          () => setState(() => _draft = _draft.copyWith(negotiable: true))),
                      _pill('Harga pas', _draft.negotiable == false,
                          () => setState(() => _draft = _draft.copyWith(negotiable: false))),
                    ]),
                  ),
                  _Section(
                    'Serah terima',
                    _wrap([
                      _pill('Semua', _draft.handover == null,
                          () => setState(() => _draft = _draft.copyWith(handover: null))),
                      for (final h in Handover.values)
                        _pill(h.label, _draft.handover == h,
                            () => setState(() => _draft = _draft.copyWith(handover: h))),
                    ]),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, 12 + bottom),
            child: Row(
              children: [
                Expanded(
                  child: OutlineBlueButton(
                    label: 'Atur Ulang',
                    height: 50,
                    fontSize: 15,
                    onTap: _reset,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GradientButton(
                    label: 'Terapkan',
                    height: 50,
                    fontSize: 15,
                    onTap: _apply,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrap(List<Widget> children) =>
      Wrap(spacing: 10, runSpacing: 10, children: children);

  Widget _pill(String label, bool selected, VoidCallback onTap) {
    return ChoicePill(
      label: label,
      selected: selected,
      onTap: onTap,
      height: 40,
      horizontal: 20,
      fontSize: 14,
    );
  }

  Widget _priceField(String label, TextEditingController c, String hint) {
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
        TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [RupiahInputFormatter(), LengthLimitingTextInputFormatter(13)],
          style: mt(size: 15, weight: FontWeight.w700, color: MC.ink),
          decoration: InputDecoration(
            isDense: true,
            prefixText: 'Rp ',
            prefixStyle: mt(size: 15, weight: FontWeight.w700, color: MC.ink),
            hintText: hint == 'Rp 0' ? '0' : hint,
            hintStyle: mt(size: 15, weight: FontWeight.w500, color: MC.slateLight),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: MC.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: MC.blue, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.child);

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Text(
              title,
              style: mt(size: 16, weight: FontWeight.w800, color: MC.ink),
            ),
          ),
          child,
        ],
      ),
    );
  }
}