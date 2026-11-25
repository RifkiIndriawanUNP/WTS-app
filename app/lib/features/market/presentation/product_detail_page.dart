import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wts/core/session/session.dart';
import 'package:wts/core/theme/app_theme.dart';
import 'package:wts/core/utils/format.dart';
import 'package:wts/core/utils/guard.dart';
import 'package:wts/features/chat/presentation/market_chat_providers.dart';
import 'package:wts/features/chat/presentation/market_chat_widgets.dart';
import 'package:wts/features/market/domain/product.dart';
import 'package:wts/features/market/presentation/market_providers.dart';
import 'package:wts/features/market/presentation/product_card.dart';
import 'package:wts/shared/models/app_user.dart';
import 'package:wts/shared/widgets/common_widgets.dart';
import 'package:wts/shared/widgets/dialogs.dart';
import 'package:wts/shared/widgets/glass.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  int _imageIndex = 0;
  bool _busy = false;

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
    int? price;
    if (withOffer) {
      price = await askOfferPrice(
        context,
        title: 'Ajukan tawaran',
        hint: 'Harga produk ${formatRp(p.price)}',
      );
      if (price == null || !mounted) return;
    }
    await _run(() async {
      final repo = ref.read(marketChatRepositoryProvider);
      final chatId = await guarded(context, () async {
        final id = await repo.openChat(p.id);
        if (price != null) await repo.sendOffer(id, price);
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(productByIdProvider(widget.productId));
    final me = ref.watch(currentUserProvider);

    return GlassScaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            ErrorState(onRetry: () => ref.invalidate(productsProvider)),
        data: (p) {
          if (p == null) {
            return SafeArea(
              child: Column(
                children: [
                  GlassHeader(title: 'Detail produk', onBack: context.pop),
                  const Expanded(
                    child: EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Produk tidak ditemukan',
                      message: 'Produk sudah dihapus atau kedaluwarsa.',
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
    final totalImages = p.photoBytesList.isNotEmpty
        ? p.photoBytesList.length
        : (p.imageUrls.isNotEmpty ? p.imageUrls.length : p.imageCount);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: 320,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      itemCount: totalImages,
                      onPageChanged: (i) => setState(() => _imageIndex = i),
                      itemBuilder: (context, i) => buildProductMedia(
                        product: p,
                        index: i,
                        iconSize: 64,
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      top: top + 8,
                      child: Row(
                        children: [
                          GlassIconButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: context.pop,
                          ),
                          const Spacer(),
                          GlassIconButton(
                            icon: saved
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            onTap: () => ref
                                .read(savedProductIdsProvider.notifier)
                                .toggle(p.id),
                          ),
                          const SizedBox(width: 8),
                          GlassIconButton(
                            icon: Icons.share_outlined,
                            onTap: () async {
                              await Clipboard.setData(
                                ClipboardData(text: 'wts://product/${p.id}'),
                              );
                              if (mounted) {
                                showSnack(context, 'Tautan produk disalin.');
                              }
                            },
                          ),
                          if (!isMine) ...[
                            const SizedBox(width: 8),
                            GlassIconButton(
                              icon: Icons.flag_outlined,
                              onTap: () => _report(p),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 28,
                      child: StatusPill(
                        label: '${_imageIndex + 1}/$totalImages',
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .92),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusPill(
                            label: p.statusLabel,
                            color: productStatusColor(p.status),
                          ),
                          const SizedBox(width: 8),
                          StatusPill(
                            label: p.isRent ? 'Sewa' : 'Jual',
                            color: AppColors.primary,
                          ),
                          const Spacer(),
                          Text(
                            'Tayang ${timeAgo(p.createdAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        p.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.priceLabel,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      if (p.isRent && p.deposit != null)
                        Text(
                          'Deposit ${formatRp(p.deposit!)}',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      if (p.negotiable)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            'Harga bisa nego',
                            style: TextStyle(color: AppColors.success),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoBox(
                              icon: Icons.verified_outlined,
                              label: 'Kondisi',
                              value: p.isUsed ? 'Second' : 'Baru',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InfoBox(
                              icon: Icons.category_outlined,
                              label: 'Kategori',
                              value: p.category,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InfoBox(
                              icon: Icons.place_outlined,
                              label: 'Titik COD',
                              value: p.meetingPoint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const _SectionTitle('Deskripsi'),
                      Text(p.description, style: const TextStyle(height: 1.45)),
                      if (p.isUsed && p.defectNote != null) ...[
                        const SizedBox(height: 16),
                        const _SectionTitle('Kekurangan produk'),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(p.defectNote!),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const _SectionTitle('Penjual'),
                      Row(
                        children: [
                          UserAvatar(user: seller, size: 46),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isMine
                                      ? '${seller.name} (kamu)'
                                      : seller.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  seller.major ?? '',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isMine) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Kedaluwarsa dalam ${remaining(p.expiresAt)} '
                          '(diperpanjang ${p.extensionCount}/3 kali)',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
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
          IconButton.outlined(
            onPressed: _busy ? null : () => _delete(p),
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: _busy || p.isSold ? null : () => _extend(p),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: const StadiumBorder(),
              ),
              child: const Text('Perpanjang'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: _busy || p.isSold ? null : () => _markSold(p),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: const StadiumBorder(),
              ),
              child: Text(p.isRent ? 'Tandai disewa' : 'Tandai terjual'),
            ),
          ),
        ],
      );
    } else if (p.isSold) {
      actions = Container(
        height: 48,
        alignment: Alignment.center,
        child: Text(
          'Produk ini sudah ${p.isRent ? 'disewa' : 'terjual'}.',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        ),
      );
    } else {
      actions = Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _chatSeller(p, withOffer: true),
              icon: const Icon(Icons.local_offer_outlined),
              label: const Text('Tawar'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: const StadiumBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _chatSeller(p),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Chat Penjual'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ],
      );
    }
    return GlassCard(
      radius: 0,
      blur: 20,
      opacity: .78,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      child: actions,
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primarySoft.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
    );
  }
}