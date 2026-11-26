import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wts/core/session/session.dart';
import 'package:wts/core/utils/format.dart';
import 'package:wts/core/utils/guard.dart';
import 'package:wts/features/chat/presentation/market_chat_providers.dart';
import 'package:wts/features/market/domain/product.dart';
import 'package:wts/features/market/presentation/market_providers.dart';
import 'package:wts/features/market/presentation/market_style.dart';
import 'package:wts/features/market/presentation/offer_sheet.dart';
import 'package:wts/shared/models/app_user.dart';
import 'package:wts/shared/widgets/app_icons.dart';
import 'package:wts/shared/widgets/common_widgets.dart';
import 'package:wts/shared/widgets/dialogs.dart';

const double _kHeroHeight = 300;

WtsIcon _categoryIcon(String c) {
  switch (c) {
    case 'IoT':
      return WtsIcons.plug;
    case 'Buku':
      return WtsIcons.fileText;
    case 'Elektronik':
      return WtsIcons.devices;
    case 'Perabot':
      return WtsIcons.chair;
    case 'Kos':
      return WtsIcons.home;
    case 'Jasa':
      return WtsIcons.settings;
    default:
      return WtsIcons.gridDots;
  }
}

class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  int _imageIndex = 0;
  bool _busy = false;
  bool _descExpanded = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chatSeller(Product p, {bool withOffer = false}) async {
    OfferDraft? draft;
    if (withOffer) {
      draft = await showOfferSheet(context, p);
      if (draft == null || !mounted) return;
    }
    await _run(() async {
      final repo = ref.read(marketChatRepositoryProvider);
      final chatId = await guarded(context, () async {
        final id = await repo.openChat(p.id);
        // TODO(chat): kirim juga draft.when & draft.place saat kontrak
        // sendOffer mendukung jadwal/tempat. Saat ini hanya harga.
        if (draft != null) await repo.sendOffer(id, draft.price);
        return id;
      });
      if (chatId != null && mounted) context.push('/chat/market/$chatId');
    });
  }

  Future<void> _markSold(Product p) async {
    final ok = await confirmDialog(
      context,
      title: p.isRent ? 'Tandai disewa?' : 'Tandai terjual?',
      message:
          'Produk ditandai ${p.isRent ? 'disewa' : 'terjual'} di luar WTS. '
          'Untuk transaksi lewat chat, gunakan tombol "Tandai terjual" di chat.',
      confirmLabel: 'Tandai',
    );
    if (!ok || !mounted) return;
    await guarded(
      context,
      () => ref
          .read(marketRepositoryProvider)
          .setStatus(p.id, ProductStatus.sold),
    );
  }

  Future<void> _extend(Product p) async {
    final done = await guarded(context, () async {
      await ref.read(marketRepositoryProvider).extendProduct(p.id);
      return true;
    });
    if (done == true && mounted) {
      showSnack(context, 'Masa tayang diperpanjang 30 hari.');
    }
  }

  Future<void> _delete(Product p) async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus produk?',
      message: 'Produk akan dihapus dan chat terkait ditutup.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final done = await guarded(context, () async {
      await ref.read(marketRepositoryProvider).deleteProduct(p.id);
      return true;
    });
    if (done == true && mounted) {
      context.pop();
      showSnack(context, 'Produk dihapus.');
    }
  }

  Future<void> _report(Product p) async {
    final reason = await pickReasonDialog(
      context,
      title: 'Laporkan produk',
      reasons: const [
        'Penipuan',
        'Barang terlarang',
        'Spam / iklan berulang',
        'Informasi tidak sesuai',
        'Lainnya',
      ],
    );
    if (reason != null && mounted) {
      showSnack(context, 'Laporan terkirim (simulasi): $reason');
    }
  }

  Future<void> _copyLink(Product p) async {
    await Clipboard.setData(ClipboardData(text: 'wts://product/${p.id}'));
    if (mounted) showSnack(context, 'Tautan produk disalin.');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(productByIdProvider(widget.productId));
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            ErrorState(onRetry: () => ref.invalidate(productsProvider)),
        data: (p) {
          if (p == null) {
            return SafeArea(
              child: Column(
                children: [
                  MarketTitleBar(
                    title: 'Detail barang',
                    onBack: () => context.pop(),
                  ),
                  const Expanded(
                    child: EmptyState(
                      icon: WtsIcons.package,
                      title: 'Barang tidak ditemukan',
                      message: 'Barang sudah dihapus atau kedaluwarsa.',
                    ),
                  ),
                ],
              ),
            );
          }
          return _content(p, me);
        },
      ),
    );
  }

  Widget _content(Product p, AppUser me) {
    final seller = userById(p.sellerId);
    final isMine = p.sellerId == me.id;
    final saved = ref.watch(
      savedProductIdsProvider.select((s) => s.contains(p.id)),
    );
    final top = MediaQuery.paddingOf(context).top;
    final total = p.totalImages;
    final style = listingStyleOf(p.listingType);
    final tagText = p.listingType == ListingType.sell
        ? 'DIJUAL'
        : (p.isRent ? 'SEWA' : 'GRATIS');
    final tagBg = p.listingType == ListingType.sell
        ? const Color(0xFFFFEDD5)
        : style.bg;
    final tagFg = p.listingType == ListingType.sell
        ? MC.orangeDeep
        : style.fg;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: _kHeroHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      itemCount: total,
                      onPageChanged: (i) => setState(() => _imageIndex = i),
                      itemBuilder: (context, i) => ProductMedia(
                        product: p,
                        index: i,
                        circle: 96,
                        iconSize: 40,
                      ),
                    ),
                    // Scrim tipis di atas foto (aset "Rectangle 8368").
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 104,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFF0F172A).withValues(alpha: .16),
                                const Color(0xFF0F172A).withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      top: top + 10,
                      child: Row(
                        children: [
                          RoundIconButton(
                            icon: WtsIcons.chevronLeft,
                            iconSize: 20,
                            size: 46,
                            background: Colors.white.withValues(alpha: .92),
                            onTap: () => context.pop(),
                          ),
                          const Spacer(),
                          _MoreMenu(
                            isMine: isMine,
                            onCopy: () => _copyLink(p),
                            onReport: () => _report(p),
                            onDelete: () => _delete(p),
                          ),
                        ],
                      ),
                    ),
                    if (total > 1)
                      Positioned(
                        right: 16,
                        bottom: 34,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_imageIndex + 1}/$total',
                            style: mt(
                              size: 12,
                              weight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -24),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: tagBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              tagText,
                              style: mt(
                                size: 12,
                                weight: FontWeight.w800,
                                color: tagFg,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            timeAgo(p.createdAt),
                            style: mt(
                              size: 13,
                              weight: FontWeight.w500,
                              color: MC.slate,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => ref
                                .read(savedProductIdsProvider.notifier)
                                .toggle(p.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: MC.line),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppIcon(
                                    saved
                                        ? WtsIcons.heartFilled
                                        : WtsIcons.heart,
                                    size: 20,
                                    color: saved ? MC.red : MC.ink,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${p.likeCount + (saved ? 1 : 0)}',
                                    style: mt(
                                      size: 14,
                                      weight: FontWeight.w800,
                                      color: MC.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        p.title,
                        style: mt(
                          size: 24,
                          weight: FontWeight.w800,
                          color: MC.ink,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.priceLabel,
                        style: mt(
                          size: 28,
                          weight: FontWeight.w800,
                          color: p.isFree ? MC.green : MC.orangeDeep,
                        ),
                      ),
                      if (p.isRent && p.deposit != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Deposit ${rp(p.deposit!)}',
                            style: mt(
                              size: 13,
                              weight: FontWeight.w500,
                              color: MC.slate,
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoBox(
                              icon: WtsIcons.circleCheck,
                              label: 'Kondisi',
                              value: p.isUsed ? 'Second' : 'Baru',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InfoBox(
                              icon: _categoryIcon(p.category),
                              label: 'Kategori',
                              value: p.category,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InfoBox(
                              icon: WtsIcons.pin,
                              label: 'Serah terima',
                              value: p.handover.label,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Deskripsi',
                        style: mt(
                          size: 16,
                          weight: FontWeight.w800,
                          color: MC.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.description,
                        maxLines: _descExpanded ? null : 3,
                        overflow: _descExpanded
                            ? TextOverflow.visible
                            : TextOverflow.fade,
                        style: mt(
                          size: 15,
                          weight: FontWeight.w500,
                          color: MC.slate,
                          height: 1.5,
                        ),
                      ),
                      if (p.description.length > 110)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _descExpanded = !_descExpanded),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 2),
                            child: Text(
                              _descExpanded ? 'Lebih sedikit' : 'Selengkapnya',
                              style: mt(
                                size: 15,
                                weight: FontWeight.w600,
                                color: MC.blue,
                              ),
                            ),
                          ),
                        ),
                      if (
                          p.defectNote != null &&
                          p.defectNote!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Minus barang',
                          style: mt(
                            size: 16,
                            weight: FontWeight.w800,
                            color: MC.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            p.defectNote!,
                            style: mt(
                              size: 14,
                              weight: FontWeight.w500,
                              color: MC.orangeDeep,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _SellerCard(seller: seller, isMine: isMine),
                      if (isMine) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Kedaluwarsa dalam ${remaining(p.expiresAt)} '
                          '(diperpanjang ${p.extensionCount}/3 kali)',
                          style: mt(
                            size: 12,
                            weight: FontWeight.w500,
                            color: MC.slate,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        _bottomBar(p, isMine),
      ],
    );
  }

  Widget _bottomBar(Product p, bool isMine) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    Widget actions;
    if (isMine) {
      actions = Row(
        children: [
          RoundIconButton(
            icon: WtsIcons.trash,
            color: MC.red,
            size: 52,
            shadow: false,
            background: Colors.white,
            onTap: _busy ? null : () => _delete(p),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlineBlueButton(
              label: 'Perpanjang',
              onTap: _busy || p.isSold ? null : () => _extend(p),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GradientButton(
              label: p.isRent ? 'Tandai disewa' : 'Tandai terjual',
              onTap: _busy || p.isSold ? null : () => _markSold(p),
            ),
          ),
        ],
      );
    } else if (p.isSold) {
      actions = SizedBox(
        height: 52,
        child: Center(
          child: Text(
            'Barang ini sudah ${p.isRent ? 'disewa' : 'terjual'}.',
            style: mt(size: 15, weight: FontWeight.w700, color: MC.slate),
          ),
        ),
      );
    } else {
      // Barang gratis tidak ditawar; harga pas hanya mengajukan waktu & tempat.
      final canOffer = !p.isFree;
      actions = Row(
        children: [
          if (canOffer) ...[
            Expanded(
              flex: 2,
              child: OutlineBlueButton(
                label: p.negotiable ? 'Tawar' : 'Ajukan',
                onTap: _busy ? null : () => _chatSeller(p, withOffer: true),
              ),
            ),
            const SizedBox(width: 20),
          ],
          Expanded(
            flex: 3,
            child: GradientButton(
              label: 'Chat Penjual',
              glow: true,
              onTap: _busy ? null : () => _chatSeller(p),
            ),
          ),
        ],
      );
    }
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(22, 14, 22, 16 + bottom),
      child: actions,
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.isMine,
    required this.onCopy,
    required this.onReport,
    required this.onDelete,
  });

  final bool isMine;
  final VoidCallback onCopy;
  final VoidCallback onReport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Lainnya',
      position: PopupMenuPosition.under,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (v) {
        switch (v) {
          case 'copy':
            onCopy();
          case 'report':
            onReport();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'copy',
          child: Text('Salin tautan', style: mt(size: 14, weight: FontWeight.w600)),
        ),
        if (!isMine)
          PopupMenuItem(
            value: 'report',
            child: Text('Laporkan', style: mt(size: 14, weight: FontWeight.w600)),
          ),
        if (isMine)
          PopupMenuItem(
            value: 'delete',
            child: Text(
              'Hapus barang',
              style: mt(size: 14, weight: FontWeight.w600, color: MC.red),
            ),
          ),
      ],
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .92),
          shape: BoxShape.circle,
          boxShadow: softShadow(.10, 14),
        ),
        child: const AppIcon(WtsIcons.moreVert, size: 22, color: MC.ink),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  final WtsIcon icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F2F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: 22, color: MC.orangeIcon),
          const SizedBox(height: 10),
          Text(
            label,
            style: mt(size: 12, weight: FontWeight.w500, color: MC.slate),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: mt(size: 14.5, weight: FontWeight.w800, color: MC.ink),
          ),
        ],
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.seller, required this.isMine});

  final AppUser seller;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E9F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFE0E7FF),
              shape: BoxShape.circle,
            ),
            child: Text(
              seller.initials,
              style: mt(size: 16, weight: FontWeight.w800, color: MC.blue),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isMine ? '${seller.name} (kamu)' : seller.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mt(
                          size: 16,
                          weight: FontWeight.w800,
                          color: MC.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const AppIcon(WtsIcons.verified, size: 18, color: MC.blue),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${seller.major ?? 'Mahasiswa'} · Mahasiswa terverifikasi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mt(size: 12, weight: FontWeight.w500, color: MC.slate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}