import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wts/core/session/session.dart';
import 'package:wts/core/utils/guard.dart';
import 'package:wts/features/chat/data/fake_market_chat_repository.dart';
import 'package:wts/features/chat/domain/chat_models.dart';
import 'package:wts/features/chat/domain/market_chat.dart';
import 'package:wts/features/chat/domain/market_chat_repository.dart';
import 'package:wts/features/chat/presentation/chat_ui.dart';
import 'package:wts/features/chat/presentation/market_chat_providers.dart';
import 'package:wts/features/chat/presentation/market_chat_sheets.dart';
import 'package:wts/features/chat/presentation/market_chat_widgets.dart';
import 'package:wts/features/chat/presentation/message_widgets.dart';
import 'package:wts/features/chat/presentation/share_flows.dart';
import 'package:wts/features/market/domain/product.dart';
import 'package:wts/features/market/presentation/market_providers.dart';
import 'package:wts/shared/models/app_user.dart';
import 'package:wts/shared/widgets/common_widgets.dart';
import 'package:wts/shared/widgets/dialogs.dart';

class MarketChatRoomPage extends ConsumerStatefulWidget {
  const MarketChatRoomPage({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<MarketChatRoomPage> createState() =>
      _MarketChatRoomPageState();
}

class _MarketChatRoomPageState extends ConsumerState<MarketChatRoomPage> {
  ReplyDraft? _reply;

  MarketChatRepository get _repo => ref.read(marketChatRepositoryProvider);

  // ----------------------------------------------------------------- kirim

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

  Future<void> _sendText(String text) async {
    final reply = _reply;
    if (reply != null) setState(() => _reply = null);
    await _send(
      MessageType.text,
      body: text,
      meta: reply == null
          ? null
          : {'replyName': reply.name, 'replyText': reply.text},
    );
  }

  Future<void> _onLongPress(ChatMessage m, String meId) async {
    if (m.isSystem || m.type == MessageType.offer) return;
    final action = await showMessageActions(
      context,
      canDelete: m.senderId == meId,
    );
    if (!mounted || action == null) return;
    if (action == 'reply') {
      setState(
        () => _reply = ReplyDraft(
          name: replyNameFor(m, meId),
          text: m.preview,
        ),
      );
    } else if (action == 'delete') {
      await _deleteMessage(m, meId);
    }
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

  // --------------------------------------------------------------- tawaran

  DateTime _tomorrowTen() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + 1, 10);
  }

  Future<void> _newOffer(MarketChat chat, AppUser peer, bool iAmSeller) async {
    final product = ref.read(productByIdProvider(chat.productId)).value;
    final base = (product?.price ?? 10000);
    final name = firstName(peer);
    final draft = await showEditOfferSheet(
      context,
      title: 'Ajukan kesepakatan',
      subtitle: '$name harus menyetujui harga, waktu, dan tempat sekaligus.',
      baseLabel: 'Harga produk ${chatRp(base)}',
      basePrice: base,
      step: iAmSeller ? 5000 : -5000,
      initialMeetAt: _tomorrowTen(),
      initialPlace: product?.meetingPoint ?? kMeetingPoints.first,
      warning:
          'Kesepakatan resmi setelah $name menyetujui harga, waktu, dan tempat.',
    );
    if (draft == null || !mounted) return;
    await guarded(
      context,
      () => _repo.sendOffer(
        widget.chatId,
        draft.price,
        meetAt: draft.meetAt,
        place: draft.place,
      ),
    );
  }

  Future<void> _counter(
    MarketChat chat,
    Offer offer,
    AppUser peer,
    bool iAmSeller,
  ) async {
    final product = ref.read(productByIdProvider(chat.productId)).value;
    final name = firstName(peer);
    final draft = await showEditOfferSheet(
      context,
      title: 'Ubah kesepakatan',
      subtitle: '$name harus menyetujui harga, waktu, dan tempat sekaligus.',
      baseLabel: 'Tawaran terakhir $name ${chatRp(offer.price)}',
      basePrice: offer.price,
      step: iAmSeller ? 5000 : -5000,
      initialMeetAt: offer.meetAt ?? _tomorrowTen(),
      initialPlace: offer.place ?? product?.meetingPoint ?? kMeetingPoints.first,
      warning:
          'Tawaran barumu menggantikan tawaran $name.\nKesepakatan resmi setelah $name menyetujui ketiganya.',
    );
    if (draft == null || !mounted) return;
    await guarded(
      context,
      () => _repo.respondOffer(
        widget.chatId,
        offer.id,
        OfferAction.counter,
        counterPrice: draft.price,
        meetAt: draft.meetAt,
        place: draft.place,
      ),
    );
  }

  Future<void> _accept(Offer offer) async {
    await guarded(
      context,
      () => _repo.respondOffer(widget.chatId, offer.id, OfferAction.accept),
    );
  }

  Future<void> _reject(Offer offer, AppUser peer) async {
    final reason = await showRejectSheet(context, peerName: firstName(peer));
    if (reason == null || !mounted) return;
    await guarded(
      context,
      () => _repo.respondOffer(
        widget.chatId,
        offer.id,
        OfferAction.reject,
        reason: reason,
      ),
    );
  }

  // -------------------------------------------------------------- progres

  Future<void> _reschedule(MarketChat chat) async {
    final current = chat.meetAt ?? _tomorrowTen();
    final time = await pickMeetTime(context, current);
    if (time == null || !mounted) return;
    final place = await showPlaceSheet(context, current: chat.place);
    if (place == null || !mounted) return;
    await guarded(
      context,
      () => _repo.updateSchedule(widget.chatId, meetAt: time, place: place),
    );
  }

  Future<void> _depart(MarketChat chat) async {
    final at = chat.meetAt;
    if (at != null) {
      final opens = at.subtract(const Duration(hours: 1));
      if (DateTime.now().isBefore(opens)) {
        showSnack(context, 'Tombol Berangkat aktif ${slotLabel(opens)}');
        return;
      }
    }
    await guarded(
      context,
      () => _repo.setProgress(widget.chatId, ChatProgress.departed),
    );
  }

  Future<void> _arrive() async {
    final ok = await confirmDialog(
      context,
      title: 'Sudah sampai di titik temu?',
      message: 'Lawan bicara akan diberi tahu bahwa kamu sudah sampai.',
      confirmLabel: 'Ya, sudah sampai',
    );
    if (!ok || !mounted) return;
    await guarded(
      context,
      () => _repo.setProgress(widget.chatId, ChatProgress.arrived),
    );
  }

  Future<void> _noShow() async {
    final ok = await confirmDialog(
      context,
      title: 'Tandai dia tidak datang?',
      message: 'Transaksi akan dibatalkan.',
      confirmLabel: 'Tandai',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await guarded(
      context,
      () => _repo.cancel(widget.chatId, 'Lawan bicara tidak datang'),
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
    if (done == true && mounted) {
      showSnack(context, 'Terima kasih atas penilaianmu!');
    }
  }

  Future<void> _simulate(PeerAction action) async {
    final repo = _repo;
    if (repo is! FakeMarketChatRepository) return;
    await guarded(context, () => repo.simulatePeer(widget.chatId, action));
  }

  void _attach(MarketChat chat, AppUser peer, bool iAmSeller) {
    Future<void> send(
      MessageType type, {
      String? body,
      Map<String, Object?>? meta,
    }) =>
        _send(type, body: body, meta: meta);
    final canOffer =
        chat.status == MarketChatStatus.negotiating && chat.pendingOffer == null;
    showAttachSheet(
      context,
      actions: buildShareActions(
        context,
        send,
        leading: [
          if (canOffer)
            ComposerAction(
              label: 'Tawar',
              icon: Icons.local_offer_outlined,
              onTap: () => _newOffer(chat, peer, iAmSeller),
            ),
        ],
      ),
      onCamera: () => sharePhoto(context, send, camera: true),
    );
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final async = ref.watch(marketChatProvider(widget.chatId));

    ref.listen(marketChatProvider(widget.chatId), (prev, next) {
      final c = next.value;
      if (c != null && c.unread > 0) _repo.markRead(widget.chatId);
    });

    return ChatScaffold(
      body: SafeArea(
        bottom: false,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            onRetry: () =>
                ref.invalidate(marketChatProvider(widget.chatId)),
          ),
          data: (chat) {
            if (chat == null) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ChatCircleButton(
                        icon: Icons.chevron_left_rounded,
                        iconSize: 30,
                        onTap: context.pop,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Chat tidak tersedia',
                    ),
                  ),
                ],
              );
            }
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

  Widget _menu(MarketChat chat, AppUser me) {
    final iAmSeller = chat.sellerId == me.id;
    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      onSelected: (v) {
        if (v.startsWith('sim:')) {
          final action = PeerAction.values
              .where((a) => a.name == v.substring(4))
              .firstOrNull;
          if (action != null) _simulate(action);
          return;
        }
        switch (v) {
          case 'info':
            showSnack(
              context,
              'Pesan chat market dihapus otomatis 3 hari setelah transaksi dibatalkan / produk terjual.',
            );
          case 'arrive':
            _arrive();
          case 'sold':
            _markSold();
          case 'cancel':
            _cancel();
          case 'rate':
            _rate();
          case 'report':
            _report();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'info', child: Text('Info chat')),
        if (chat.isActiveDeal && !chat.arrived.containsKey(me.id))
          const PopupMenuItem(
            value: 'arrive',
            child: Text('Saya sudah sampai'),
          ),
        if (iAmSeller && chat.isActiveDeal)
          const PopupMenuItem(value: 'sold', child: Text('Tandai terjual')),
        if (chat.status == MarketChatStatus.negotiating || chat.isActiveDeal)
          const PopupMenuItem(
            value: 'cancel',
            child: Text('Batalkan transaksi'),
          ),
        if (chat.status == MarketChatStatus.sold && !chat.ratedByMe)
          const PopupMenuItem(value: 'rate', child: Text('Beri penilaian')),
        const PopupMenuItem(value: 'report', child: Text('Laporkan')),
        if (kDebugMode && _repo is FakeMarketChatRepository)
          for (final a in PeerAction.values)
            PopupMenuItem(
              value: 'sim:${a.name}',
              child: Text('Simulasi: ${a.name}'),
            ),
      ],
      child: const ChatCircle(icon: Icons.more_vert_rounded),
    );
  }

  Widget _room(MarketChat chat, AppUser me) {
    final peer = userById(chat.otherId(me.id));
    final iAmSeller = chat.sellerId == me.id;
    final product = ref.watch(productByIdProvider(chat.productId)).value;
    final pending = chat.pendingOffer;
    final peerName = firstName(peer);
    final place = chat.place ?? product?.meetingPoint ?? 'titik temu';

    final showStepper = chat.status != MarketChatStatus.cancelled &&
        chat.status != MarketChatStatus.closed;

    // Pesan "sampai" terakhir -> tempat kartu serah terima ditampilkan.
    String? lastArrivedMsgId;
    for (final m in chat.messages) {
      if (m.meta['kind'] == 'arrived') lastArrivedMsgId = m.id;
    }

    Widget item(ChatMessage m) {
      final kind = m.meta['kind'];
      final actor = m.meta['actor'] as String?;

      if (m.type == MessageType.offer) {
        final id = m.meta['offerId'];
        final offer = chat.offers.where((o) => o.id == id).firstOrNull;
        if (offer == null) return const SizedBox.shrink();
        final isCurrent = pending != null &&
            pending.id == offer.id &&
            chat.status == MarketChatStatus.negotiating;
        if (!isCurrent) {
          return OfferHistoryCard(
            offer: offer,
            meId: me.id,
            peer: peer,
            me: me,
            createdAt: m.createdAt,
          );
        }
        return OfferFullCard(
          offer: offer,
          meId: me.id,
          peer: peer,
          me: me,
          listPrice: product?.price,
          createdAt: m.createdAt,
          onEdit: () => _counter(chat, offer, peer, iAmSeller),
          onAccept: () => _accept(offer),
          onReject: () => _reject(offer, peer),
        );
      }

      if (m.isSystem) {
        switch (kind) {
          case 'agreed':
            final at = chat.meetAt;
            final live = chat.status == MarketChatStatus.agreed ||
                chat.status == MarketChatStatus.onTheWay;
            return Column(
              children: [
                SystemChip(message: m, meId: me.id),
                if (at != null && live)
                  ScheduleCard(
                    meetAt: at,
                    place: place,
                    departEnabled: !DateTime.now()
                        .isBefore(at.subtract(const Duration(hours: 1))),
                    departed: chat.departed.containsKey(me.id),
                    onChange: () => _reschedule(chat),
                    onDepart: () => _depart(chat),
                  ),
              ],
            );
          case 'departed':
            final mineDeparted = actor == me.id;
            final canArrive = mineDeparted &&
                chat.isActiveDeal &&
                !chat.arrived.containsKey(me.id);
            return TrackingCard(
              actorName: mineDeparted ? 'Kamu' : peerName,
              place: place,
              departedAt: (actor == null ? null : chat.departed[actor]) ??
                  m.createdAt,
              onTap: canArrive ? _arrive : null,
            );
          case 'arrived':
            final extra = <Widget>[];
            if (chat.status == MarketChatStatus.arrived) {
              if (actor == me.id && !chat.bothArrived) {
                extra.add(
                  ArrivalWaitCard(
                    peerName: peerName,
                    arrivedAt: chat.arrived[me.id] ?? m.createdAt,
                    onRemind: () => _send(
                      MessageType.text,
                      body: 'Aku sudah sampai di titik temu, kamu di mana?',
                    ),
                    onNoShow: _noShow,
                    onCancel: _cancel,
                  ),
                );
              } else if (actor != me.id && !chat.arrived.containsKey(me.id)) {
                extra.add(
                  StatusActionCard(
                    icon: Icons.location_on_outlined,
                    title: '$peerName sudah di titik temu',
                    message: 'Temui dia di $place.',
                    primaryLabel: 'Saya sudah sampai',
                    onPrimary: _arrive,
                  ),
                );
              } else if (chat.bothArrived && m.id == lastArrivedMsgId) {
                extra.add(
                  StatusActionCard(
                    icon: Icons.handshake_outlined,
                    title: 'Kalian sudah bertemu',
                    message: iAmSeller
                        ? 'Konfirmasi setelah pembayaran kamu terima.'
                        : 'Menunggu $peerName mengonfirmasi pembayaran.',
                    primaryLabel: iAmSeller ? 'Pembayaran diterima' : null,
                    onPrimary: iAmSeller ? _markSold : null,
                  ),
                );
              }
            }
            return Column(
              children: [SystemChip(message: m, meId: me.id), ...extra],
            );
          case 'sold':
            return Column(
              children: [
                SystemChip(message: m, meId: me.id),
                DoneCard(
                  chat: chat,
                  meId: me.id,
                  peer: peer,
                  productTitle: product?.title,
                  onProblem: _report,
                ),
              ],
            );
        }
      }

      return MessageBubble(
        message: m,
        meId: me.id,
        market: true,
        onLongPress: () => _onLongPress(m, me.id),
      );
    }

    final items = <Widget>[
      ChatProductCard(
        product: product,
        chat: chat,
        onTap: () => context.push('/market/product/${chat.productId}'),
      ),
      if (showStepper) ...[
        const SizedBox(height: 12),
        DealStepper(chat: chat),
      ],
      const SizedBox(height: 4),
      ...buildChatItems(chat.messages, item),
    ];

    final Widget bottom;
    switch (chat.status) {
      case MarketChatStatus.sold:
        bottom = const LockedPanel(
          text:
              'Obrolan dikunci. Tidak bisa kirim pesan baru, riwayat tersimpan 7 hari untuk laporan.',
        );
      case MarketChatStatus.cancelled:
        bottom = const LockedPanel(
          text:
              'Transaksi dibatalkan. Tidak bisa kirim pesan baru, riwayat tersimpan 3 hari.',
        );
      case MarketChatStatus.closed:
        bottom = const LockedPanel(
          text:
              'Produk sudah terjual. Obrolan dikunci, riwayat tersimpan 3 hari.',
        );
      case MarketChatStatus.negotiating:
      case MarketChatStatus.agreed:
      case MarketChatStatus.onTheWay:
      case MarketChatStatus.arrived:
        final spot = (product?.meetingPoint ?? 'kampus').toLowerCase();
        final negotiating = chat.status == MarketChatStatus.negotiating;
        bottom = MarketInputPanel(
          defaults: negotiating
              ? [
                  'Boleh COD di $spot?',
                  'Harga masih bisa nego?',
                  'Sudah sampai lokasi',
                  'Terima kasih kak',
                ]
              : const [
                  'Saya sampai 5 menit lagi',
                  'Saya sudah sampai',
                  'Saya sedang jalan',
                  'Terima kasih kak',
                ],
          onSend: _sendText,
          onAttach: () => _attach(chat, peer, iAmSeller),
          reply: _reply,
          onCloseReply: () => setState(() => _reply = null),
        );
    }

    return Column(
      children: [
        ChatRoomHeader(
          user: peer,
          subtitle: peer.online ? 'Sedang aktif' : '@${peer.username}',
          subtitleColor: peer.online ? ChatColors.activeGreen : ChatColors.muted,
          onBack: context.pop,
          menu: _menu(chat, me),
        ),
        Expanded(
          child: ChatListView(
            changeToken: Object.hash(
              chat.messages.length,
              chat.status,
              chat.offers.length,
              chat.arrived.length,
            ),
            children: items,
          ),
        ),
        bottom,
      ],
    );
  }
}