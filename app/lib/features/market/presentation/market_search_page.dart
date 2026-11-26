import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wts/features/market/domain/product.dart';
import 'package:wts/features/market/presentation/market_filter_sheet.dart';
import 'package:wts/features/market/presentation/market_providers.dart';
import 'package:wts/features/market/presentation/market_style.dart';
import 'package:wts/features/market/presentation/product_card.dart';
import 'package:wts/shared/widgets/common_widgets.dart';

const _kTabs = <String>['Semua', 'Dijual', 'Disewakan', 'Gratis'];
const _kTabTypes = <ListingType?>[
  null,
  ListingType.sell,
  ListingType.rent,
  ListingType.free,
];

/// Pencarian Market: riwayat & populer -> saran saat mengetik -> hasil.
class MarketSearchPage extends ConsumerStatefulWidget {
  const MarketSearchPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<MarketSearchPage> createState() => _MarketSearchPageState();
}

class _MarketSearchPageState extends ConsumerState<MarketSearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    Future.microtask(() {
      if (!mounted) return;
      ref.read(searchFilterProvider.notifier).replace(const MarketFilter());
      if (widget.initialQuery.isNotEmpty) {
        _controller.text = widget.initialQuery;
        _submit(widget.initialQuery);
      } else {
        _focus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final q = raw.trim();
    if (q.isEmpty) return;
    _controller.value = TextEditingValue(
      text: q,
      selection: TextSelection.collapsed(offset: q.length),
    );
    ref.read(recentSearchesProvider.notifier).add(q);
    ref.read(searchFilterProvider.notifier).setQuery(q);
    _focus.unfocus();
    setState(() => _submitted = true);
  }

  void _fill(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() => _submitted = false);
    _focus.requestFocus();
  }

  void _clear() {
    _controller.clear();
    setState(() => _submitted = false);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final typing = _focus.hasFocus || !_submitted;
    final text = _controller.text;
    final showResults = _submitted && !_focus.hasFocus;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: MarketBackdrop(
        style: MarketBackdropStyle.cool,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _topBar(showFilter: !(typing && text.isNotEmpty)),
              Expanded(
                child: showResults
                    ? _Results(query: text.trim())
                    : _Panel(
                        child: text.trim().isEmpty
                            ? _Idle(onPick: (q) => _submit(q))
                            : _Suggestions(
                                query: text.trim(),
                                onSubmit: _submit,
                                onFill: _fill,
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar({required bool showFilter}) {
    final hasText = _controller.text.isNotEmpty;
    final filterCount = ref.watch(searchFilterProvider).activeCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            iconSize: 20,
            size: 48,
            onTap: () => context.pop(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 50,
              padding: const EdgeInsets.only(left: 16, right: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .95),
                borderRadius: BorderRadius.circular(25),
                boxShadow: softShadow(.10, 16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 22, color: MC.ink),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      textInputAction: TextInputAction.search,
                      cursorColor: MC.blue,
                      onChanged: (_) => setState(() => _submitted = false),
                      onSubmitted: _submit,
                      style: mt(size: 15, weight: FontWeight.w600, color: MC.ink),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'Cari barang, buku, alat praktik',
                        hintStyle: mt(
                          size: 14,
                          weight: FontWeight.w500,
                          color: MC.slate,
                        ),
                      ),
                    ),
                  ),
                  if (hasText && _focus.hasFocus)
                    GestureDetector(
                      onTap: _clear,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.cancel_outlined,
                          size: 24,
                          color: MC.ink,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (showFilter) ...[
            const SizedBox(width: 10),
            Stack(
              clipBehavior: Clip.none,
              children: [
                RoundIconButton(
                  icon: Icons.filter_alt_outlined,
                  size: 48,
                  iconSize: 24,
                  onTap: () =>
                      showMarketFilterSheet(context, searchFilterProvider),
                ),
                if (filterCount > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: MC.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Panel putih berujung membulat di bawah bilah pencarian.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: child,
    );
  }
}

class _Idle extends ConsumerWidget {
  const _Idle({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSearchesProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
      children: [
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              Text(
                'Pencarian terakhir',
                style: mt(size: 17, weight: FontWeight.w800, color: MC.ink),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => ref.read(recentSearchesProvider.notifier).clear(),
                child: Text(
                  'Hapus semua',
                  style: mt(size: 14, weight: FontWeight.w700, color: MC.blue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final q in recent)
            InkWell(
              onTap: () => onPick(q),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEF1F6),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: const Icon(Icons.schedule_rounded, size: 16, color: MC.slate),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        q,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mt(
                          size: 16,
                          weight: FontWeight.w700,
                          color: MC.text,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          ref.read(recentSearchesProvider.notifier).remove(q),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: MC.slateLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
        ],
        Text(
          'Pencarian populer',
          style: mt(size: 17, weight: FontWeight.w800, color: MC.ink),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final q in kPopularSearches)
              GestureDetector(
                onTap: () => onPick(q),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F1FE),
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: const Color(0xFFD3E1F8)),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      q,
                      style: mt(size: 14, weight: FontWeight.w700, color: MC.text),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Suggestions extends ConsumerWidget {
  const _Suggestions({
    required this.query,
    required this.onSubmit,
    required this.onFill,
  });

  final String query;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onFill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    final items = searchSuggestions(query, products);
    final q = query.toLowerCase();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        for (final s in items)
          InkWell(
            onTap: () => onSubmit(s),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF2F8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      size: 24,
                      color: Color(0xFF5B6B8C),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: s.toLowerCase().startsWith(q)
                                ? s.substring(0, q.length)
                                : '',
                            style: mt(
                              size: 16,
                              weight: FontWeight.w800,
                              color: MC.ink,
                            ),
                          ),
                          TextSpan(
                            text: s.toLowerCase().startsWith(q)
                                ? s.substring(q.length)
                                : s,
                            style: mt(
                              size: 16,
                              weight: FontWeight.w500,
                              color: MC.ink,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onFill(s),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.north_west_rounded,
                        size: 20,
                        color: MC.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(searchFilterProvider);
    final results = ref.watch(searchResultsProvider);
    final tab = _kTabTypes.indexOf(filter.type).clamp(0, _kTabs.length - 1);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: PillSegmented(
            labels: _kTabs,
            index: tab,
            height: 44,
            fontSize: 14,
            onChanged: (i) =>
                ref.read(searchFilterProvider.notifier).setType(_kTabTypes[i]),
          ),
        ),
        Expanded(
          child: results.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorState(
              onRetry: () => ref.invalidate(productsProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Barang tidak ditemukan',
                  message: 'Coba kata kunci lain atau ubah filter.',
                );
              }
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(26, 14, 20, 10),
                      child: Text(
                        '${list.length} barang',
                        style: mt(
                          size: 13,
                          weight: FontWeight.w500,
                          color: MC.slate,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + bottom),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        mainAxisExtent: kCardExtentWithPill,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => ProductCard(
                          product: list[i],
                          showTypePill: true,
                          highlight: query,
                          onTap: () =>
                              context.push('/market/product/${list[i].id}'),
                        ),
                        childCount: list.length,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}