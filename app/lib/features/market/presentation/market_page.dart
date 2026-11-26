import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wts/core/router/nav_collapse.dart';
import 'package:wts/features/market/presentation/market_filter_sheet.dart';
import 'package:wts/features/market/presentation/market_providers.dart';
import 'package:wts/features/market/presentation/market_style.dart';
import 'package:wts/features/market/presentation/product_card.dart';
import 'package:wts/shared/widgets/app_icons.dart';
import 'package:wts/shared/widgets/common_widgets.dart';

/// Urutan chip kategori di beranda Market (sesuai desain).
const _kChipOrder = <String>[
  'IoT',
  'Buku',
  'Elektronik',
  'Kos',
  'Perabot',
  'Jasa',
  'Lainnya',
];

/// Scroll melewati ambang ini -> navigasi menyusut & header jadi pil melayang.
const double _kCollapseAt = 150;
const double _kExpandAt = 60;

/// Jarak antara tombol `+` dan kapsul navigasi di bawahnya.
const double _kFabGap = 12;

class MarketPage extends ConsumerStatefulWidget {
  const MarketPage({super.key});

  @override
  ConsumerState<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends ConsumerState<MarketPage> {
  final _scroll = ScrollController();

  // --- Dock vertikal (tombol header yang pindah ke tepi saat scroll) ---
  final _anchors = [for (final id in DockId.values) DockAnchor(id)];
  int _dockMask = 0;
  bool _compact = false;
  bool _scrollingDown = true;
  double _lastY = 0;
  double _acc = 0;
  double _favTrigger = double.infinity;
  double _searchTrigger = double.infinity;
  double _topInset = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onTick);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onTick);
    _scroll.dispose();
    for (final a in _anchors) {
      a.active.dispose();
    }
    super.dispose();
  }

  /// Ukur posisi tombol header (koordinat konten) agar terbang dari titik asal.
  void _measure() {
    if (!mounted) return;
    final off = _scroll.hasClients ? _scroll.offset : 0.0;
    for (final a in _anchors) {
      final box = a.key.currentContext?.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) {
        final g = box.localToGlobal(Offset.zero);
        a.rect = Rect.fromLTWH(g.dx, g.dy + off, box.size.width, box.size.height);
      }
    }
    final fav = _anchors[DockId.favorite.index].rect;
    final orders = _anchors[DockId.orders.index].rect;
    final search = _anchors[DockId.search.index].rect;
    if (fav != null && orders != null && search != null) {
      _favTrigger = (fav.top < orders.top ? fav.top : orders.top) - _topInset;
      _searchTrigger = search.top - _topInset;
    }
  }

  void _onTick() {
    if (!_scroll.hasClients) return;
    final y = _scroll.offset < 0 ? 0.0 : _scroll.offset;
    final d = y - _lastY;
    _lastY = y;
    if (d != 0) {
      if ((d > 0) != (_acc > 0)) _acc = 0;
      _acc += d;
      if (_acc.abs() > 12) _scrollingDown = _acc > 0;
    }

    // Histeresis kecil agar tidak berkedip di ambang.
    final favOut = y > _favTrigger - (_dockMask != 0 ? 8 : 0);
    final searchOut = y > _searchTrigger - (_dockMask & 4 != 0 ? 8 : 0);

    if (!searchOut || !_scrollingDown && _acc.abs() > 12) {
      _compact = false; // scroll ke atas / search kembali terlihat -> 4 / 2 awal
    } else if (_scrollingDown && y > _searchTrigger + 70) {
      _compact = true; // scroll terus ke bawah -> cukup cari + pesanan
    }

    final int mask;
    if (!favOut) {
      mask = 0;
    } else if (!searchOut) {
      mask = 3; // favorit + pesanan
    } else if (_compact) {
      mask = (1 << DockId.orders.index) | (1 << DockId.search.index);
    } else {
      mask = 15; // semua: favorit, pesanan, cari, filter
    }
    if (mask != _dockMask) setState(() => _dockMask = mask);
  }

  /// Offset saat navigasi dibuka manual (ketuk lingkaran). Navigasi baru
  /// menyusut lagi setelah pengguna scroll turun cukup jauh dari titik ini.
  double _manualExpandAt = -1000;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final y = n.metrics.pixels;
    final collapsed = ref.read(navCollapsedProvider);
    final notifier = ref.read(navCollapsedProvider.notifier);
    if (collapsed) {
      if (y <= _kExpandAt) notifier.set(false);
    } else if (y > _kCollapseAt && y > _manualExpandAt + 60) {
      notifier.set(true);
    }
    return false;
  }

  void _openSearch() => context.push('/market/search');
  void _openFavorites() => context.push('/market/favorites');
  void _openTransactions() => context.push('/market/transactions');
  void _openFilter() => showMarketFilterSheet(context, marketFilterProvider);

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(marketFilterProvider);
    final products = ref.watch(visibleProductsProvider);
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    // Status navigasi (menyusut/terbuka) dibagi dengan MainShell, sehingga
    // tombol `+` ikut naik saat lingkaran diketuk dan kapsul memanjang.
    final collapsed = ref.watch(navCollapsedProvider);
    ref.listen<bool>(navCollapsedProvider, (prev, next) {
      if (prev == true && !next && _scroll.hasClients) {
        _manualExpandAt = _scroll.offset;
      }
    });
    _topInset = top;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    // FAB "+" : di atas kapsul saat penuh, sejajar lingkaran saat menyusut.
    final fabBottom = collapsed
        ? navCircleBottom(context)
        : navBottomGap(context) + kNavHeight + _kFabGap;

    return Scaffold(
      backgroundColor: MC.bg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: RefreshIndicator(
              edgeOffset: top,
              onRefresh: () async {
                ref.invalidate(productsProvider);
                await ref.read(productsProvider.future);
              },
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(
                      top: top,
                      filterCount: filter.activeCount,
                      category: filter.category,
                      onSearch: _openSearch,
                      onFilter: _openFilter,
                      onFavorites: _openFavorites,
                      onTransactions: _openTransactions,
                      anchors: _anchors,
                      onCategory: (c) => ref
                          .read(marketFilterProvider.notifier)
                          .setCategory(c),
                    ),
                  ),
                  products.when(
                    loading: () => SliverPadding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 140 + bottom),
                      sliver: _grid(
                        count: 6,
                        builder: (_, _) => const SkeletonBox(radius: 16),
                      ),
                    ),
                    error: (e, _) => SliverFillRemaining(
                      hasScrollBody: false,
                      child: ErrorState(
                        onRetry: () => ref.invalidate(productsProvider),
                      ),
                    ),
                    data: (list) {
                      if (list.isEmpty) {
                        return const SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyState(
                            icon: WtsIcons.search,
                            title: 'Belum ada barang',
                            message:
                                'Coba ubah filter, atau jadilah yang pertama memposting.',
                          ),
                        );
                      }
                      return SliverMainAxisGroup(
                        slivers: [
                          SliverToBoxAdapter(
                            child: _CountRow(
                              count: list.length,
                              sort: filter.sort,
                              onSort: (s) => ref
                                  .read(marketFilterProvider.notifier)
                                  .setSort(s),
                            ),
                          ),
                          SliverPadding(
                            padding:
                                EdgeInsets.fromLTRB(20, 4, 20, 150 + bottom),
                            sliver: _grid(
                              count: list.length,
                              builder: (context, i) => ProductCard(
                                product: list[i],
                                onTap: () => context
                                    .push('/market/product/${list[i].id}'),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Dock vertikal di tepi kanan (tombol header yang berpindah).
          ..._dockLayer(top, filter.activeCount > 0),

          // Tombol "+".
          AnimatedPositioned(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeInOutCubic,
            right: collapsed ? kNavCollapsedLeft : kNavSideGap,
            bottom: fabBottom,
            child: _AddFab(onTap: () => context.push('/market/new')),
          ),
        ],
      ),
    );
  }

  List<Widget> _dockLayer(double top, bool filterActive) {
    final width = MediaQuery.sizeOf(context).width;
    final dockLeft = width - _kDockRight - _kDockWidth + (_kDockWidth - _kDockBtn) / 2;
    final dockTop = top + 40;

    int slotOf(DockId id) {
      var n = 0;
      for (var i = 0; i < id.index; i++) {
        if (_dockMask & (1 << i) != 0) n++;
      }
      return n;
    }

    Widget btn(
      DockId id,
      WtsIcon icon,
      VoidCallback onTap, {
      String? hint,
      bool dot = false,
    }) {
      final a = _anchors[id.index];
      return _DockButton(
        anchor: a,
        scroll: _scroll,
        docked: _dockMask & a.bit != 0,
        slot: slotOf(id),
        dockLeft: dockLeft,
        dockTop: dockTop,
        topInset: top,
        icon: icon,
        onTap: onTap,
        hint: hint,
        showDot: dot,
      );
    }

    return [
      Positioned(
        right: _kDockRight,
        top: dockTop,
        child: _DockCapsule(count: _popcount(_dockMask)),
      ),
      btn(DockId.favorite, WtsIcons.heart, _openFavorites),
      btn(DockId.orders, WtsIcons.bag, _openTransactions),
      btn(
        DockId.search,
        WtsIcons.search,
        _openSearch,
        hint: 'Cari buku, gawai, catatan kuliah',
      ),
      btn(
        DockId.filter,
        WtsIcons.filter,
        _openFilter,
        dot: filterActive,
      ),
    ];
  }

  SliverGrid _grid({
    required int count,
    required Widget Function(BuildContext, int) builder,
  }) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        mainAxisExtent: kCardExtentPlain,
      ),
      delegate: SliverChildBuilderDelegate(builder, childCount: count),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.top,
    required this.filterCount,
    required this.category,
    required this.onSearch,
    required this.onFilter,
    required this.onFavorites,
    required this.onTransactions,
    required this.onCategory,
    required this.anchors,
  });

  final List<DockAnchor> anchors;
  final double top;
  final int filterCount;
  final String? category;
  final VoidCallback onSearch;
  final VoidCallback onFilter;
  final VoidCallback onFavorites;
  final VoidCallback onTransactions;
  final ValueChanged<String?> onCategory;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: WarmGlow()),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: top + 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const WtsLogoMark(size: 42),
                  const SizedBox(width: 8),
                  Text(
                    'WTS Market',
                    style: mt(
                      size: 18,
                      weight: FontWeight.w800,
                      color: MC.orange,
                    ),
                  ),
                  const Spacer(),
                  _Anchor(
                    anchor: anchors[DockId.favorite.index],
                    child: RoundIconButton(
                      icon: WtsIcons.heart,
                      size: 44,
                      onTap: onFavorites,
                      tooltip: 'Favorit',
                    ),
                  ),
                  const SizedBox(width: 12),
                  _Anchor(
                    anchor: anchors[DockId.orders.index],
                    child: RoundIconButton(
                      icon: WtsIcons.bag,
                      size: 44,
                      onTap: onTransactions,
                      tooltip: 'Transaksi saya',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Cari apa\n',
                      style: mt(
                        size: 32,
                        weight: FontWeight.w800,
                        color: MC.ink,
                        height: 1.15,
                      ),
                    ),
                    TextSpan(
                      text: 'hari ini?',
                      style: mt(
                        size: 32,
                        weight: FontWeight.w800,
                        color: MC.orange,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Barang kuliah, kos, sampai jasa dari sesama\nmahasiswa Nusa Putra.',
                style: mt(
                  size: 14,
                  weight: FontWeight.w500,
                  color: MC.slate,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Row(
                children: [
                  Expanded(
                    child: _Anchor(
                      anchor: anchors[DockId.search.index],
                      child: _SearchBox(onTap: onSearch),
                    ),
                  ),
                  const SizedBox(width: 14),
                  _Anchor(
                    anchor: anchors[DockId.filter.index],
                    child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      RoundIconButton(
                        icon: WtsIcons.filter,
                        size: 52,
                        iconSize: 24,
                        onTap: onFilter,
                        tooltip: 'Filter',
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
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _CategoryChip(
                    label: 'Semua',
                    selected: category == null,
                    onTap: () => onCategory(null),
                  ),
                  for (final c in _kChipOrder) ...[
                    const SizedBox(width: 10),
                    _CategoryChip(
                      label: c,
                      selected: category == c,
                      onTap: () => onCategory(category == c ? null : c),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(26),
        boxShadow: softShadow(.10, 16),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const AppIcon(WtsIcons.search, size: 22, color: MC.slate),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cari buku, gawai, catatan kuliah',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mt(
                      size: 14,
                      weight: FontWeight.w500,
                      color: MC.slateLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? MC.blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? MC.blue : MC.line),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: MC.blue.withValues(alpha: .28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: mt(
            size: 14,
            weight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : MC.text,
          ),
        ),
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.count,
    required this.sort,
    required this.onSort,
  });

  final int count;
  final MarketSort sort;
  final ValueChanged<MarketSort> onSort;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 6, 24, 10),
      child: Row(
        children: [
          Text(
            '$count barang',
            style: mt(size: 13, weight: FontWeight.w500, color: MC.slate),
          ),
          const Spacer(),
          PopupMenuButton<MarketSort>(
            onSelected: onSort,
            position: PopupMenuPosition.under,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
            itemBuilder: (_) => [
              for (final s in MarketSort.values)
                PopupMenuItem(
                  value: s,
                  child: Text(
                    s.label,
                    style: mt(
                      size: 14,
                      weight: s == sort ? FontWeight.w700 : FontWeight.w500,
                      color: s == sort ? MC.blue : MC.text,
                    ),
                  ),
                ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sort.label,
                  style: mt(size: 13, weight: FontWeight.w600, color: MC.ink),
                ),
                const SizedBox(width: 2),
                const AppIcon(
                  WtsIcons.chevronDown,
                  size: 20,
                  color: MC.ink,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================ Dock vertikal

/// Tombol yang bisa "terbang" dari posisi aslinya di header ke dock kanan.
/// Urutan id = urutan slot dari atas: favorit, pesanan, cari, filter.
enum DockId { favorite, orders, search, filter }

class DockAnchor {
  DockAnchor(this.id);

  final DockId id;
  final GlobalKey key = GlobalKey();

  /// true selama tombol melayang (tombol asli di header disembunyikan).
  final ValueNotifier<bool> active = ValueNotifier(false);

  /// Posisi & ukuran di koordinat konten scroll (diukur setelah layout).
  Rect? rect;

  int get bit => 1 << id.index;
}

int _popcount(int v) {
  var n = 0;
  while (v != 0) {
    n += v & 1;
    v >>= 1;
  }
  return n;
}

/// Pembungkus tombol header: disembunyikan saat versi melayangnya aktif.
class _Anchor extends StatelessWidget {
  const _Anchor({required this.anchor, required this.child});

  final DockAnchor anchor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: anchor.active,
      builder: (context, on, child) => IgnorePointer(
        ignoring: on,
        child: Opacity(opacity: on ? 0 : 1, child: child),
      ),
      child: KeyedSubtree(key: anchor.key, child: child),
    );
  }
}

const double _kDockBtn = 46;
const double _kDockPadV = 4;
const double _kDockWidth = 50;
const double _kDockRight = 14;

/// Latar kapsul dock: tingginya mengikuti jumlah tombol yang menempel.
class _DockCapsule extends StatelessWidget {
  const _DockCapsule({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    const ms = Duration(milliseconds: 360);
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: count > 0 ? 1 : 0,
        child: AnimatedContainer(
          duration: ms,
          curve: Curves.easeInOutCubic,
          width: _kDockWidth,
          height: count == 0 ? 0 : count * _kDockBtn + _kDockPadV * 2,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: MC.peachButton.withValues(alpha: .97),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white),
            boxShadow: softShadow(.14, 18),
          ),
          child: Stack(
            children: [
              for (var i = 1; i < 4; i++)
                Positioned(
                  left: 14,
                  right: 14,
                  top: _kDockPadV + i * _kDockBtn - .5,
                  child: AnimatedOpacity(
                    duration: ms,
                    opacity: i < count ? 1 : 0,
                    child: Container(
                      height: 1,
                      color: MC.orange.withValues(alpha: .18),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Satu tombol dock. Saat [docked] false ia mengikuti posisi aslinya di header
/// (ikut ter-scroll); saat true ia terbang ke slot di tepi kanan, mengecil
/// dari bentuk aslinya (kotak pencarian -> lingkaran) menjadi ikon polos.
class _DockButton extends StatefulWidget {
  const _DockButton({
    required this.anchor,
    required this.scroll,
    required this.docked,
    required this.slot,
    required this.dockLeft,
    required this.dockTop,
    required this.topInset,
    required this.icon,
    required this.onTap,
    this.hint,
    this.showDot = false,
  });

  final DockAnchor anchor;
  final ScrollController scroll;
  final bool docked;

  /// Urutan slot di antara tombol yang menempel (0 = paling atas).
  final int slot;
  final double dockLeft;
  final double dockTop;
  final double topInset;
  final WtsIcon icon;
  final VoidCallback onTap;
  final String? hint;
  final bool showDot;

  @override
  State<_DockButton> createState() => _DockButtonState();
}

class _DockButtonState extends State<_DockButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..addListener(_sync);

  void _sync() {
    final on = _c.value > 0 || widget.docked;
    if (widget.anchor.active.value != on) widget.anchor.active.value = on;
  }

  /// Slot terakhir saat masih menempel: tombol yang collapse memudar di sini
  /// (tidak bergerak keluar kolom dock).
  int _lastSlot = 0;

  @override
  void didUpdateWidget(covariant _DockButton old) {
    super.didUpdateWidget(old);
    if (widget.docked != old.docked) {
      widget.docked ? _c.forward() : _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.docked) _lastSlot = widget.slot;
    final slotY = widget.dockTop + _kDockPadV + _lastSlot * _kDockBtn;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: slotY),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
      builder: (context, y, _) {
        return AnimatedBuilder(
          animation: Listenable.merge([_c, widget.scroll]),
          builder: (context, _) => _frame(y),
        );
      },
    );
  }

  Widget _frame(double slotY) {
    final r = widget.anchor.rect;
    if (r == null || _c.value == 0) return const SizedBox.shrink();
    final raw = Curves.easeInOutCubic.transform(_c.value);
    final offset = widget.scroll.hasClients ? widget.scroll.offset : 0.0;
    final originY = r.top - offset;
    final originTop = originY < widget.topInset ? widget.topInset : originY;
    // Asal masih terlihat di layar -> terbang antara header <-> dock.
    // Asal sudah di luar layar (mis. favorit/filter saat dock jadi 2 tombol)
    // -> tidak terbang: diam di slotnya, hanya memudar masuk/keluar.
    final originVisible = originY + r.height * .5 > widget.topInset;
    final t = originVisible ? raw : 1.0;
    final opacity = originVisible ? 1.0 : Curves.easeIn.transform(_c.value);

    final w = r.width + (_kDockBtn - r.width) * t;
    final h = r.height + (_kDockBtn - r.height) * t;
    final left = r.left + (widget.dockLeft - r.left) * t;
    final top = originTop + (slotY - originTop) * t;
    final isBox = widget.hint != null;

    return Positioned(
      left: left,
      top: top,
      width: w,
      height: h,
      child: Opacity(
        opacity: opacity,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Color.lerp(
              Colors.white.withValues(alpha: .92),
              Colors.white.withValues(alpha: 0),
              t,
            ),
            borderRadius: BorderRadius.circular(h / 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: .10 * (1 - t)),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onTap,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isBox)
                    // Lebar isi dikunci ke lebar asli kotak lalu dipotong,
                    // supaya Row tidak overflow saat kotak mengecil.
                    ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: 0,
                        maxWidth: r.width,
                        child: SizedBox(
                          width: r.width,
                          height: h,
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 18 + (12 - 18) * t,
                              right: 8,
                            ),
                            child: Row(
                              children: [
                                AppIcon(
                                  widget.icon,
                                  size: 22,
                                  color: Color.lerp(MC.slate, MC.ink, t),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Opacity(
                                    opacity: (1 - t * 2).clamp(0.0, 1.0),
                                    child: Text(
                                      widget.hint!,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.clip,
                                      style: mt(
                                        size: 14,
                                        weight: FontWeight.w500,
                                        color: MC.slateLight,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    AppIcon(widget.icon, size: 22, color: MC.ink),
                  if (widget.showDot)
                    Positioned(
                      right: 9,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: MC.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddFab extends StatelessWidget {
  const _AddFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kNavCircle,
      height: kNavCircle,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: MC.blue,
        boxShadow: [
          BoxShadow(
            color: MC.blue.withValues(alpha: .42),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const AppIcon(WtsIcons.plus, size: 30, color: Colors.white),
        ),
      ),
    );
  }
}