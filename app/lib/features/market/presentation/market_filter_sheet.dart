import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wts/core/theme/app_theme.dart';
import 'package:wts/core/utils/format.dart';
import 'package:wts/features/market/domain/product.dart';
import 'package:wts/features/market/presentation/market_providers.dart';
import 'package:wts/shared/widgets/common_widgets.dart';
import 'package:wts/shared/widgets/glass.dart';

Future<void> showMarketFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const MarketFilterSheet(),
  );
}

class MarketFilterSheet extends ConsumerStatefulWidget {
  const MarketFilterSheet({super.key});

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
    _draft = ref.read(marketFilterProvider);
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
    final next = _draft.copyWith(
      minPrice: parseRupiah(_min.text),
      maxPrice: parseRupiah(_max.text),
    );
    ref.read(marketFilterProvider.notifier).replace(next);
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _reset() {
    setState(() {
      _draft = _draft.copyWith(
        type: null,
        condition: null,
        minPrice: null,
        maxPrice: null,
        onlyAvailable: false,
        onlyNegotiable: false,
        sort: MarketSort.newest,
      );
      _min.clear();
      _max.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassSheet(
      title: 'Filter & urutkan',
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Label('Jenis'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GlassChip(
                  label: 'Semua',
                  selected: _draft.type == null,
                  onTap: () => setState(() => _draft = _draft.copyWith(type: null)),
                ),
                GlassChip(
                  label: 'Jual',
                  selected: _draft.type == ListingType.sell,
                  onTap: () => setState(
                    () => _draft = _draft.copyWith(type: ListingType.sell),
                  ),
                ),
                GlassChip(
                  label: 'Sewa',
                  selected: _draft.type == ListingType.rent,
                  onTap: () => setState(
                    () => _draft = _draft.copyWith(type: ListingType.rent),
                  ),
                ),
              ],
            ),
            const _Label('Kondisi'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GlassChip(
                  label: 'Semua',
                  selected: _draft.condition == null,
                  onTap: () =>
                      setState(() => _draft = _draft.copyWith(condition: null)),
                ),
                GlassChip(
                  label: 'Baru',
                  selected: _draft.condition == ItemCondition.brandNew,
                  onTap: () => setState(
                    () => _draft =
                        _draft.copyWith(condition: ItemCondition.brandNew),
                  ),
                ),
                GlassChip(
                  label: 'Second',
                  selected: _draft.condition == ItemCondition.used,
                  onTap: () => setState(
                    () => _draft =
                        _draft.copyWith(condition: ItemCondition.used),
                  ),
                ),
              ],
            ),
            const _Label('Rentang harga'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _min,
                    keyboardType: TextInputType.number,
                    inputFormatters: [RupiahInputFormatter()],
                    decoration: glassInput(hint: 'Minimum', prefixText: 'Rp '),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('-'),
                ),
                Expanded(
                  child: TextField(
                    controller: _max,
                    keyboardType: TextInputType.number,
                    inputFormatters: [RupiahInputFormatter()],
                    decoration: glassInput(hint: 'Maksimum', prefixText: 'Rp '),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hanya yang tersedia'),
              value: _draft.onlyAvailable,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(onlyAvailable: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Harga bisa nego'),
              value: _draft.onlyNegotiable,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(onlyNegotiable: v)),
            ),
            const _Label('Urutkan'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in const {
                  MarketSort.newest: 'Terbaru',
                  MarketSort.priceAsc: 'Harga terendah',
                  MarketSort.priceDesc: 'Harga tertinggi',
                  MarketSort.endingSoon: 'Segera berakhir',
                }.entries)
                  GlassChip(
                    label: entry.value,
                    selected: _draft.sort == entry.key,
                    onTap: () => setState(
                      () => _draft = _draft.copyWith(sort: entry.key),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _apply,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Terapkan'),
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }
}