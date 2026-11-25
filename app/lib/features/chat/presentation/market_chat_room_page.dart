import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wts/core/session/session.dart';
import 'package:wts/core/utils/format.dart';
import 'package:wts/core/utils/guard.dart';
import 'package:wts/features/chat/domain/chat_models.dart';
import 'package:wts/features/chat/domain/market_chat_repository.dart';
import 'package:wts/features/chat/presentation/message_widgets.dart';
import 'package:wts/features/chat/presentation/share_flows.dart';
import 'package:wts/features/chat/data/fake_market_chat_repository.dart';
import 'package:wts/features/chat/domain/market_chat.dart';
import 'package:wts/features/chat/presentation/market_chat_providers.dart';
import 'package:wts/features/chat/presentation/market_chat_widgets.dart';
import 'package:wts/features/market/presentation/market_providers.dart';
import 'package:wts/shared/models/app_user.dart';
import 'package:wts/shared/widgets/common_widgets.dart';
import 'package:wts/shared/widgets/dialogs.dart';
import 'package:wts/shared/widgets/glass.dart';

class MarketChatRoomPage extends ConsumerStatefulWidget {
  const MarketChatRoomPage({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<MarketChatRoomPage> createState() =>
      _MarketChatRoomPageState();
}

class _MarketChatRoomPageState extends ConsumerState<MarketChatRoomPage> {
  MarketChatRepository get _repo => ref.read(marketChatRepositoryProvider);

  Future<void> _send(
    MessageType type, {
    String? body,
    Map<String, Object?>? meta,
  }) async {
    await guarded(
      context,
      () => _repo.sendMessage(
        widget.chatId,
        type,
        body: body,
        meta: meta ?? const {},
      ),
    );
  }

  Future<void> _newOffer(MarketChat chat) async {
    final product = ref.read(productByIdProvider(chat.productId)).value;
    final price = await askOfferPrice(
      context,
      title: 'Ajukan tawaran',
      hint: product == null ? null : 'Harga produk ${formatRp(product.price)}',
    );
    if (price == null || !mounted) return;
    await guarded(context, () => _repo.sendOffer(widget.chatId, price));
  }

  Future<void> _counter(MarketChat chat, Offer offer) async {
    final price = await askOfferPrice(
      context,
      title: 'Tawar balik',
      hint: 'Tawaran terakhir ${formatRp(offer.price)}',
    );
    if (price == null || !mounted) return;
    await guarded(
      context,
      () => _repo.respondOffer(
        widget.chatId,
        offer.id,
        OfferAction.counter,
        counterPrice: price,
      ),
    );
  }

  Future<void> _respond(Offer offer, OfferAction action) async {
    await guarded(
      context,
      () => _repo.respondOffer(widget.chatId, offer.id, action),
    );
  }

  Future<void> _markSold() async {
    final ok = await confirmDialog(
      context,
      title: 'Tandai terjual?',
      message: 'Lakukan setelah serah terima barang dan pembayaran selesai. '
          'Chat pembeli lain pada produk ini akan ditutup.',
      confirmLabel: 'Tandai terjual',
    );
    if (!ok || !mounted) return;
    await guarded(context, () => _repo.markSold(widget.chatId));
  }

  Future<void> _cancel() async {
    final reason = await pickReasonDialog(
      context,
      title: 'Batalkan transaksi?',
      reasons: const [
        'Tidak jadi membeli / menjual',
        'Harga tidak cocok',
        'Lawan bicara tidak responsif',
        'Barang tidak sesuai',
        'Lainnya',
      ],
    );
    if (reason == null || !mounted) return;
    await guarded(context, () => _repo.cancel(widget.chatId, reason));
  }

  Future<void> _report() async {
    final reason = await pickReasonDialog(
      context,
      title: 'Laporkan penipuan / pelanggaran',
      reasons: const [
        'Penipuan',
        'Pelecehan / perundungan',
        'Barang terlarang',
        'Spam',
        'Lainnya',
      ],
    );
    if (reason != null && mounted) {
      showSnack(
        context,
        'Laporan terkirim (simulasi). 20 pesan terakhir disimpan sebagai bukti.',
      );
    }
  }

  Future<void> _rate() async {
    final result = await showRatingSheet(context);
    if (result == null || !mounted) return;
    final done = await guarded(context, () async {
      await _repo.rate(widget.chatId, result.stars, result.comment);
      return true;
    });
    if (done == true && mounted) showSnack(context, 'Terima kasih atas penilaianmu!');
  }

  Future<void> _deleteMessage(ChatMessage m, String meId) async {
    if (m.senderId != meId || m.isSystem || m.type == MessageType.offer) return;
    final ok = await confirmDialog(
      context,
      title: 'Hapus pesan?',
      message: 'Pesan dihapus untuk semua orang (maks. 15 menit setelah dikirim).',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await guarded(context, () => _repo.deleteMessage(widget.chatId, m.id));
  }

  Future<void> _simulate(PeerAction action) async {
    final repo = _repo;
    if (repo is! FakeMarketChatRepository) return;
    await guarded(context, () => repo.simulatePeer(widget.chatId, action));
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final async = ref.watch(marketChatProvider(widget.chatId));

    // Tandai terbaca saat ada pesan masuk selama ruang chat terbuka.
    ref.listen(marketChatProvider(widget.chatId), (prev, next) {
      final chat = next.value;
      if (chat != null && chat.unread > 0) {
        _repo.markRead(widget.chatId);
      }
    });

    return GlassScaffold(
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            onRetry: () => ref.invalidate(marketChatProvider(widget.chatId)),
          ),
          data: (chat) {
            if (chat == null) {
              return Column(
                children: [
                  GlassHeader(title: 'Chat', onBack: context.pop),
                  const Expanded(
                    child: EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Chat tidak tersedia',
                      message:
                          'Chat ini sudah dihapus otomatis sesuai aturan retensi.',
                    ),
                  ),
                ],
              );
            }
            // Pertama kali dibuka dengan pesan belum dibaca.
            if (chat.unread > 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _repo.markRead(widget.chatId);
              });
            }
            return _room(chat, me);
          },
        ),
      ),
    );
  }

  Widget _room(MarketChat chat, AppUser me) {
    final other = userById(chat.otherId(me.id));
    final product = ref.watch(productByIdProvider(chat.productId)).value;
    final isSeller = chat.sellerId == me.id;

    return Column(
      children: [
        GlassHeader(
          title: other.name,
          subtitle: isSeller ? 'Pembeli' : 'Penjual',
          onBack: context.pop,
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                switch (v) {
                  case 'report':
                    _report();
                  case 'cancel':
                    _cancel();
                  default:
                    final action = PeerAction.values
                        .where((a) => 'sim_${a.name}' == v)
                        .firstOrNull;
                    if (action != null) _simulate(action);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'report',
                  child: Text('Laporkan penipuan'),
                ),
                if (chat.status == MarketChatStatus.negotiating ||
                    chat.isActiveDeal)
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Text('Batalkan transaksi'),
                  ),
                if (kDebugMode &&
                    _repo is FakeMarketChatRepository &&
                    !chat.isReadOnly) ...[
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    enabled: false,
                    child: Text(
                      'Simulasi lawan bicara',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'sim_reply',
                    child: Text('Balas pesan'),
                  ),
                  const PopupMenuItem(
                    value: 'sim_sendOffer',
                    child: Text('Kirim tawaran'),
                  ),
                  const PopupMenuItem(
                    value: 'sim_acceptOffer',
                    child: Text('Terima tawaranku'),
                  ),
                  const PopupMenuItem(
                    value: 'sim_rejectOffer',
                    child: Text('Tolak tawaranku'),
                  ),
                  const PopupMenuItem(
                    value: 'sim_counterOffer',
                    child: Text('Tawar balik'),
                  ),
                  const PopupMenuItem(
                    value: 'sim_depart',
                    child: Text('Dia berangkat'),
                  ),
                  const PopupMenuItem(
                    value: 'sim_arrive',
                    child: Text('Dia sudah sampai'),
                  ),
                  const PopupMenuItem(
                    value: 'sim_markSold',
                    child: Text('Dia tandai terjual'),
                  ),
                ],
              ],
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ChatProductCard(
            product: product,
            chat: chat,
            onTap: () => context.push('/market/product/${chat.productId}'),
          ),
        ),
        if (chat.isActiveDeal || chat.status == MarketChatStatus.sold)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: DealStepper(status: chat.status),
          ),
        _retentionBanner(chat),
        if (chat.status == MarketChatStatus.negotiating)
          const RetentionBanner(
            icon: Icons.shield_outlined,
            text: 'Tips COD: bertemu di area kampus yang ramai pada siang hari, '
                'cek barang sebelum bayar, jangan transfer uang muka.',
          ),
        const SizedBox(height: 4),
        Expanded(
          child: MessageList(
            messages: chat.messages,
            meId: me.id,
            onLongPress: (m) => _deleteMessage(m, me.id),
            offerBuilder: (context, m) {
              final offerId = m.meta['offerId'] as String?;
              final offer =
                  chat.offers.where((o) => o.id == offerId).firstOrNull;
              if (offer == null) return const SizedBox.shrink();
              return OfferCard(
                offer: offer,
                mine: offer.fromUser == me.id,
                chatStatus: chat.status,
                listPrice: product?.price,
                onAccept: () => _respond(offer, OfferAction.accept),
                onReject: () => _respond(offer, OfferAction.reject),
                onCounter: () => _counter(chat, offer),
              );
            },
          ),
        ),
        _dealActions(chat, isSeller),
        ChatComposer(
          enabled: !chat.isReadOnly,
          disabledHint: chat.status == MarketChatStatus.closed
              ? 'Produk sudah terjual. Chat ditutup.'
              : 'Transaksi dibatalkan.',
          onSend: (text) => _send(MessageType.text, body: text),
          actions: buildShareActions(
            context,
            (type, {body, meta}) => _send(type, body: body, meta: meta),
            leading: [
              if (chat.status == MarketChatStatus.negotiating)
                ComposerAction(
                  label: 'Tawar',
                  icon: Icons.local_offer_outlined,
                  onTap: () => _newOffer(chat),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _retentionBanner(MarketChat chat) {
    String text;
    switch (chat.status) {
      case MarketChatStatus.negotiating:
        text = chat.deleteAt == null
            ? 'Chat negosiasi dihapus otomatis 3 hari setelah aktivitas terakhir.'
            : 'Chat dihapus otomatis dalam ${remaining(chat.deleteAt!)} '
                'jika tidak ada aktivitas.';
      case MarketChatStatus.agreed:
      case MarketChatStatus.onTheWay:
      case MarketChatStatus.arrived:
        text = 'Chat transaksi dihapus otomatis 7 hari setelah barang terjual.';
      case MarketChatStatus.sold:
        text = 'Chat dihapus otomatis dalam '
            '${chat.deleteAt == null ? '7 hari' : remaining(chat.deleteAt!)}.';
      case MarketChatStatus.cancelled:
        text = 'Transaksi dibatalkan. Chat dihapus dalam '
            '${chat.deleteAt == null ? '3 hari' : remaining(chat.deleteAt!)}.';
      case MarketChatStatus.closed:
        text = 'Produk sudah terjual. Chat hanya-baca dan dihapus dalam '
            '${chat.deleteAt == null ? '3 hari' : remaining(chat.deleteAt!)}.';
    }
    return RetentionBanner(text: text);
  }

  /// Tombol aksi sesuai status & peran (berangkat / sampai / terjual / nilai).
  Widget _dealActions(MarketChat chat, bool isSeller) {
    final buttons = <Widget>[];
    if (chat.status == MarketChatStatus.agreed) {
      buttons.add(
        _actionButton(
          'Saya berangkat',
          Icons.directions_walk_rounded,
          () => guarded(
            context,
            () => _repo.setProgress(widget.chatId, ChatProgress.departed),
          ),
        ),
      );
    }
    if (chat.status == MarketChatStatus.agreed ||
        chat.status == MarketChatStatus.onTheWay) {
      buttons.add(
        _actionButton(
          'Saya sudah sampai',
          Icons.place_rounded,
          () => guarded(
            context,
            () => _repo.setProgress(widget.chatId, ChatProgress.arrived),
          ),
        ),
      );
    }
    if (isSeller && chat.isActiveDeal) {
      buttons.add(
        _actionButton(
          'Tandai terjual',
          Icons.check_circle_outline_rounded,
          _markSold,
          filled: true,
        ),
      );
    }
    if (chat.status == MarketChatStatus.sold && !chat.ratedByMe) {
      buttons.add(
        _actionButton(
          'Beri penilaian',
          Icons.star_outline_rounded,
          _rate,
          filled: true,
        ),
      );
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Wrap(spacing: 8, runSpacing: 8, children: buttons),
    );
  }

  Widget _actionButton(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool filled = false,
  }) {
    final style = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size(0, 40)),
      shape: WidgetStateProperty.all(const StadiumBorder()),
    );
    return filled
        ? FilledButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: style,
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: style,
          );
  }
}
