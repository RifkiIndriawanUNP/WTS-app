import 'package:flutter/material.dart';
import 'package:wts/core/theme/app_theme.dart';
import 'package:wts/core/utils/format.dart';
import 'package:wts/features/chat/domain/market_chat.dart';
import 'package:wts/features/market/domain/product.dart';
import 'package:wts/features/market/presentation/product_card.dart';
import 'package:wts/shared/widgets/common_widgets.dart';
import 'package:wts/shared/widgets/dialogs.dart';
import 'package:wts/shared/widgets/glass.dart';

/// Dialog input harga tawaran (format otomatis 1.000, 10.000). Null jika batal.
Future<int?> askOfferPrice(
  BuildContext context, {
  required String title,
  String? hint,
}) async {
  final text = await textInputDialog(
    context,
    title: title,
    message: hint,
    hint: '0',
    prefixText: 'Rp ',
    keyboardType: TextInputType.number,
    formatters: [RupiahInputFormatter()],
    confirmLabel: 'Kirim',
    validator: (v) {
      final n = parseRupiah(v);
      if (n == null || n <= 0) return 'Masukkan harga';
      if (n > 100000000) return 'Maksimal Rp100.000.000';
      return null;
    },
  );
  return text == null ? null : parseRupiah(text);
}

/// Kartu produk di bagian atas ruang chat market.
class ChatProductCard extends StatelessWidget {
  const ChatProductCard({
    super.key,
    required this.product,
    required this.chat,
    required this.onTap,
  });

  final Product? product;
  final MarketChat chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final price = chat.agreedPrice ?? p?.price;
    return GlassCard(
      blur: 0,
      radius: 18,
      padding: const EdgeInsets.all(10),
      onTap: p == null ? null : onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 54,
              height: 54,
              child: ImagePlaceholder(seed: p?.seed ?? 1, iconSize: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p?.title ?? 'Produk tidak tersedia',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      price == null ? '-' : formatRp(price),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (chat.agreedPrice != null && p != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        formatRp(p.price),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (p != null)
            StatusPill(
              label: p.statusLabel,
              color: productStatusColor(p.status),
            ),
        ],
      ),
    );
  }
}

/// Stepper status transaksi: Sepakat > Berangkat > Sampai > Terjual.
class DealStepper extends StatelessWidget {
  const DealStepper({super.key, required this.status});

  final MarketChatStatus status;

  static const _labels = ['Sepakat', 'Berangkat', 'Sampai', 'Terjual'];

  /// Indeks langkah terakhir yang selesai (-1 = belum ada).
  int get _done {
    switch (status) {
      case MarketChatStatus.agreed:
        return 0;
      case MarketChatStatus.onTheWay:
        return 1;
      case MarketChatStatus.arrived:
        return 2;
      case MarketChatStatus.sold:
        return 3;
      case MarketChatStatus.negotiating:
      case MarketChatStatus.cancelled:
      case MarketChatStatus.closed:
        return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _done;
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= done
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: .8),
                    border: Border.all(
                      color: i <= done ? AppColors.primary : AppColors.line,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    i <= done ? Icons.check_rounded : Icons.circle,
                    size: i <= done ? 16 : 6,
                    color: i <= done ? Colors.white : AppColors.line,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: i <= done ? FontWeight.w700 : FontWeight.w500,
                    color: i <= done ? AppColors.primary : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (i < _labels.length - 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Container(
                  height: 2,
                  color: i < done ? AppColors.primary : AppColors.line,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Kartu tawaran di dalam percakapan.
class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.offer,
    required this.mine,
    required this.chatStatus,
    this.listPrice,
    this.onAccept,
    this.onReject,
    this.onCounter,
  });

  final Offer offer;
  final bool mine;
  final MarketChatStatus chatStatus;
  final int? listPrice;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCounter;

  @override
  Widget build(BuildContext context) {
    final status = offer.effectiveStatus;
    final canRespond = !mine &&
        status == OfferStatus.pending &&
        chatStatus == MarketChatStatus.negotiating;

    String statusText;
    Color statusColor;
    switch (status) {
      case OfferStatus.pending:
        statusText = mine
            ? 'Menunggu respons (berakhir ${remaining(offer.expiresAt)})'
            : 'Menunggu responsmu';
        statusColor = AppColors.warning;
      case OfferStatus.accepted:
        statusText = 'Disepakati';
        statusColor = AppColors.success;
      case OfferStatus.rejected:
        statusText = 'Ditolak';
        statusColor = AppColors.danger;
      case OfferStatus.countered:
        statusText = 'Ditawar balik';
        statusColor = AppColors.muted;
      case OfferStatus.expired:
        statusText = 'Kedaluwarsa';
        statusColor = AppColors.muted;
    }

    return GlassCard(
      blur: 0,
      radius: 18,
      opacity: .85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_offer_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                mine ? 'Tawaranmu' : 'Tawaran harga',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatRp(offer.price),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              if (listPrice != null && listPrice != offer.price) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    formatRp(listPrice!),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              color: statusColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (canRespond) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onAccept,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Setuju'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCounter,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Tawar lagi'),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: onReject,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Tolak'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Sheet penilaian 1-5 bintang setelah transaksi selesai.
Future<({int stars, String? comment})?> showRatingSheet(BuildContext context) {
  return showModalBottomSheet<({int stars, String? comment})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _RatingSheet(),
  );
}

class _RatingSheet extends StatefulWidget {
  const _RatingSheet();

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _stars = 5;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassSheet(
      title: 'Beri penilaian',
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () => setState(() => _stars = i),
                    iconSize: 36,
                    icon: Icon(
                      i <= _stars
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: AppColors.warning,
                    ),
                  ),
              ],
            ),
            TextField(
              controller: _comment,
              maxLines: 2,
              maxLength: 200,
              decoration: glassInput(hint: 'Ulasan singkat (opsional)'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                final c = _comment.text.trim();
                Navigator.of(context).pop(
                  (stars: _stars, comment: c.isEmpty ? null : c),
                );
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: const StadiumBorder(),
              ),
              child: const Text('Kirim penilaian'),
            ),
          ],
        ),
      ),
    );
  }
}
