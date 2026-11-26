import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wts/core/utils/format.dart';
import 'package:wts/features/chat/domain/chat_models.dart';
import 'package:wts/features/chat/domain/market_chat.dart';
import 'package:wts/features/chat/presentation/chat_ui.dart';
import 'package:wts/features/chat/presentation/message_widgets.dart';
import 'package:wts/features/market/domain/product.dart';
import 'package:wts/shared/models/app_user.dart';
import 'package:wts/shared/widgets/app_icons.dart';
import 'package:wts/shared/widgets/dialogs.dart';
import 'package:wts/shared/widgets/product_image.dart';

/// Dialog input harga tawaran (format otomatis 1.000, 10.000). Null jika batal.
/// (Masih dipakai halaman detail produk.)
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

// ------------------------------------------------------------ kartu produk

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

  ChatTone _tone() {
    switch (chat.status) {
      case MarketChatStatus.negotiating:
        return ChatTone.warning;
      case MarketChatStatus.agreed:
      case MarketChatStatus.onTheWay:
      case MarketChatStatus.arrived:
        return ChatTone.info;
      case MarketChatStatus.sold:
        return ChatTone.success;
      case MarketChatStatus.cancelled:
      case MarketChatStatus.closed:
        return ChatTone.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = product;
    final tone = _tone();
    final colors = tone == ChatTone.warning
        ? (bg: ChatColors.amberBg, fg: const Color(0xFFC2570C))
        : toneColors(tone);
    return GestureDetector(
      onTap: p == null ? null : onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: chatCardDecoration(radius: 20),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ProductImage(productId: chat.productId, iconSize: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p?.title ?? 'Produk tidak tersedia',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: ChatColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p == null ? '-' : chatRp(p.price),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: ChatColors.orange,
                    ),
                  ),
                ],
              ),
            ),
            ChatPill(
              label: marketStatusLabel(chat.status),
              background: colors.bg,
              foreground: colors.fg,
              fontSize: 14,
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- stepper

enum _StepState { done, active, warn, pending }

class DealStepper extends StatelessWidget {
  const DealStepper({super.key, required this.chat});

  final MarketChat chat;

  static const _labels = ['Sepakat', 'Berangkat', 'Sampai', 'Terjual'];

  String? _hm(DateTime? t) => t == null ? null : dotClock(t);

  @override
  Widget build(BuildContext context) {
    final dep = _hm(chat.firstDepartedAt);
    List<_StepState> s;
    List<String?> sub;
    List<double> fill;
    switch (chat.status) {
      case MarketChatStatus.negotiating:
        s = [
          _StepState.warn,
          _StepState.pending,
          _StepState.pending,
          _StepState.pending,
        ];
        sub = [chat.pendingOffer == null ? null : '1/2', null, null, null];
        fill = [0, 0, 0];
      case MarketChatStatus.agreed:
        s = [
          _StepState.done,
          _StepState.active,
          _StepState.pending,
          _StepState.pending,
        ];
        sub = [
          '2/2',
          chat.meetAt == null ? null : slotLabel(chat.meetAt!),
          null,
          null,
        ];
        fill = [1, 0, 0];
      case MarketChatStatus.onTheWay:
        s = [
          _StepState.done,
          _StepState.active,
          _StepState.pending,
          _StepState.pending,
        ];
        sub = ['2/2', dep, null, null];
        fill = [1, 1, 0];
      case MarketChatStatus.arrived:
        if (chat.bothArrived) {
          s = [
            _StepState.done,
            _StepState.done,
            _StepState.done,
            _StepState.active,
          ];
          sub = ['2/2', dep, _hm(chat.lastArrivedAt), 'Menunggu'];
          fill = [1, 1, 1];
        } else {
          s = [
            _StepState.done,
            _StepState.done,
            _StepState.active,
            _StepState.pending,
          ];
          sub = ['2/2', dep, 'Menunggu', null];
          fill = [1, 1, .5];
        }
      case MarketChatStatus.sold:
        s = List.filled(4, _StepState.done);
        sub = ['2/2', dep, _hm(chat.lastArrivedAt), _hm(chat.soldAt)];
        fill = [1, 1, 1];
      case MarketChatStatus.cancelled:
      case MarketChatStatus.closed:
        s = List.filled(4, _StepState.pending);
        sub = [null, null, null, null];
        fill = [0, 0, 0];
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      decoration: chatCardDecoration(radius: 20),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / 4;
          return SizedBox(
            height: 76,
            child: Stack(
              children: [
                for (var i = 0; i < 3; i++)
                  Positioned(
                    left: w * i + w / 2 + 19,
                    top: 16,
                    width: w - 38,
                    height: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Stack(
                        children: [
                          Container(color: const Color(0xFFD9DFEC)),
                          FractionallySizedBox(
                            widthFactor: fill[i],
                            child: Container(color: ChatColors.blue),
                          ),
                        ],
                      ),
                    ),
                  ),
                Row(
                  children: [
                    for (var i = 0; i < 4; i++)
                      Expanded(
                        child: _StepColumn(
                          label: _labels[i],
                          sub: sub[i],
                          state: s[i],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StepColumn extends StatelessWidget {
  const _StepColumn({
    required this.label,
    required this.sub,
    required this.state,
  });

  final String label;
  final String? sub;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final pending = state == _StepState.pending;
    final Widget circle;
    switch (state) {
      case _StepState.done:
        circle = Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: ChatColors.blue,
            shape: BoxShape.circle,
          ),
          child: const AppIcon(WtsIcons.check, color: Colors.white, size: 20),
        );
      case _StepState.active:
        circle = Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: ChatColors.blue, width: 2.5),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: ChatColors.blue,
              shape: BoxShape.circle,
            ),
          ),
        );
      case _StepState.warn:
        circle = Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4DC),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE8890C), width: 2.5),
          ),
          child: const AppIcon(
            WtsIcons.clock,
            size: 18,
            color: Color(0xFFE8890C),
          ),
        );
      case _StepState.pending:
        circle = Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FC),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFCBD2E0), width: 2),
          ),
        );
    }
    return Column(
      children: [
        circle,
        const SizedBox(height: 8),
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: pending ? FontWeight.w600 : FontWeight.w800,
            color: pending ? const Color(0xFF9AA3B5) : ChatColors.ink,
          ),
        ),
        if (sub != null)
          Text(
            sub!,
            maxLines: 1,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: state == _StepState.warn
                  ? ChatColors.muted
                  : (pending ? const Color(0xFF9AA3B5) : ChatColors.blue),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- tawaran

String _validity(Offer o) {
  final d = o.expiresAt.difference(DateTime.now());
  if (d.isNegative) return 'Kedaluwarsa';
  if (d.inHours >= 24) return 'Berlaku ${d.inDays} hari';
  if (d.inHours >= 1) return 'Berlaku ${d.inHours} jam';
  return 'Berlaku ${math.max(1, d.inMinutes)} mnt';
}

/// Baris pesan market: avatar + isi. Saya di kanan, lawan di kiri.
class _AvatarRow extends StatelessWidget {
  const _AvatarRow({required this.user, required this.mine, required this.child});

  final AppUser user;
  final bool mine;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final avatar = ChatAvatar(user: user, size: 46);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: mine
            ? [Flexible(child: child), const SizedBox(width: 8), avatar]
            : [avatar, const SizedBox(width: 8), Flexible(child: child)],
      ),
    );
  }
}

/// Kartu kesepakatan yang sedang menunggu (harga + waktu + tempat).
class OfferFullCard extends StatelessWidget {
  const OfferFullCard({
    super.key,
    required this.offer,
    required this.meId,
    required this.peer,
    required this.me,
    required this.listPrice,
    required this.createdAt,
    required this.onEdit,
    required this.onAccept,
    required this.onReject,
  });

  final Offer offer;
  final String meId;
  final AppUser peer;
  final AppUser me;
  final int? listPrice;
  final DateTime createdAt;
  final VoidCallback onEdit;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  bool get _mine => offer.fromUser == meId;

  Widget _row(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13.5, color: ChatColors.muted),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mine = _mine;
    final peerName = firstName(peer);
    final at = offer.meetAt;
    final proposer = mine ? 'Kamu' : peerName;
    final other = mine ? peerName : 'Kamu';

    final card = Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: chatCardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(
                WtsIcons.tag,
                size: 17,
                color: ChatColors.orange,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  mine ? 'Kesepakatan darimu' : 'Kesepakatan dari $peerName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: ChatColors.orange,
                  ),
                ),
              ),
              Text(
                _validity(offer),
                style: const TextStyle(fontSize: 12.5, color: ChatColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: ChatColors.line),
          const SizedBox(height: 4),
          _row(
            'Harga',
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 8,
              children: [
                Text(
                  chatRp(offer.price),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: ChatColors.ink,
                  ),
                ),
                if (listPrice != null && listPrice != offer.price)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      chatRp(listPrice!),
                      style: const TextStyle(
                        fontSize: 13,
                        color: ChatColors.hint,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (at != null)
            _row(
              'Waktu',
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    '${dayShort(at)} · ${dotClock(at)}',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: ChatColors.ink,
                    ),
                  ),
                  ChatPill(
                    label: daysUntilLabel(at),
                    background: const Color(0xFFE8EEFF),
                    foreground: const Color(0xFF2F55D4),
                    fontSize: 11.5,
                    radius: 8,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                  ),
                ],
              ),
            ),
          if (offer.place != null)
            _row(
              'Tempat',
              Text(
                offer.place!,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: ChatColors.ink,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChatPill(
                label: '$proposer · setuju',
                icon: WtsIcons.check,
                background: ChatColors.greenBg,
                foreground: ChatColors.greenText,
                radius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              ChatPill(
                label: '$other · menunggu',
                icon: WtsIcons.clock,
                background: const Color(0xFFFEF0CD),
                foreground: const Color(0xFF92400E),
                radius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ],
          ),
          if (!mine) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ChatButton(
                    label: 'Ubah',
                    height: 44,
                    onTap: onEdit,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChatButton(
                    label: 'Setujui',
                    icon: WtsIcons.check,
                    filled: true,
                    height: 44,
                    onTap: onAccept,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: onReject,
                style: TextButton.styleFrom(
                  foregroundColor: ChatColors.red,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Tolak kesepakatan',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              dotClock(createdAt),
              style: const TextStyle(fontSize: 12, color: ChatColors.hint),
            ),
          ),
        ],
      ),
    );
    return _AvatarRow(user: mine ? me : peer, mine: mine, child: card);
  }
}

/// Tawaran yang sudah lewat (ditolak / ditawar balik / kedaluwarsa).
class OfferHistoryCard extends StatelessWidget {
  const OfferHistoryCard({
    super.key,
    required this.offer,
    required this.meId,
    required this.peer,
    required this.me,
    required this.createdAt,
  });

  final Offer offer;
  final String meId;
  final AppUser peer;
  final AppUser me;
  final DateTime createdAt;

  String _short(String? r) {
    if (r == null || r.isEmpty) return '';
    var s = r;
    if (s.startsWith('Harga ')) s = s.substring(6);
    return s[0].toLowerCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final mine = offer.fromUser == meId;
    final status = offer.effectiveStatus;

    String pill;
    Color pillBg;
    Color pillFg;
    switch (status) {
      case OfferStatus.rejected:
        final why = _short(offer.rejectReason);
        pill = why.isEmpty ? 'Ditolak' : 'Ditolak\n$why';
        pillBg = const Color(0xFFFDE3E3);
        pillFg = const Color(0xFFD9382C);
      case OfferStatus.countered:
        pill = 'Ditawar\nbalik';
        pillBg = const Color(0xFFE6E9F0);
        pillFg = ChatColors.text2;
      case OfferStatus.accepted:
        pill = 'Disepakati';
        pillBg = ChatColors.greenBg;
        pillFg = ChatColors.greenText;
      case OfferStatus.expired:
      case OfferStatus.pending:
        pill = 'Kedaluwarsa';
        pillBg = const Color(0xFFE6E9F0);
        pillFg = ChatColors.text2;
    }

    final card = CustomPaint(
      foregroundPainter: DashedRRectPainter(
        color: mine ? const Color(0xFFC5CBDA) : const Color(0xFFA5B4FC),
        radius: 22,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFD),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mine ? 'Kamu menawar' : '${firstName(peer)} menawar',
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: ChatColors.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        chatRp(offer.price),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: ChatColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    pill,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: pillFg,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                dotClock(createdAt),
                style: const TextStyle(fontSize: 12, color: ChatColors.hint),
              ),
            ),
          ],
        ),
      ),
    );
    return _AvatarRow(
      user: mine ? me : peer,
      mine: mine,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: card,
      ),
    );
  }
}

// ------------------------------------------------------------------ jadwal

class ScheduleCard extends StatelessWidget {
  const ScheduleCard({
    super.key,
    required this.meetAt,
    required this.place,
    required this.departEnabled,
    required this.departed,
    required this.onChange,
    required this.onDepart,
  });

  final DateTime meetAt;
  final String place;

  /// Tombol "Berangkat" sudah boleh ditekan (1 jam sebelum waktu temu).
  final bool departEnabled;

  /// Saya sudah menekan Berangkat.
  final bool departed;
  final VoidCallback onChange;
  final VoidCallback onDepart;

  String _hariH() {
    final d = meetAt.difference(DateTime.now());
    if (!sameDay(meetAt, DateTime.now())) {
      return daysUntilLabel(meetAt) == 'Besok'
          ? 'Besok'
          : 'H-${math.max(1, d.inDays)}';
    }
    return d.isNegative ? 'Hari H · sudah waktunya' : 'Hari H · ${remaining(meetAt)} lagi';
  }

  Widget _bullet(WtsIcon icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          AppIcon(icon, size: 20, color: ChatColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13.5, color: ChatColors.text2),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final opens = meetAt.subtract(const Duration(hours: 1));
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A2563EB),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2848C9), Color(0xFF4272F8)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayAbbr(meetAt),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .6,
                      ),
                    ),
                    Text(
                      '${meetAt.day}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    Text(
                      monthAbbr(meetAt),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ChatPill(
                      label: _hariH(),
                      background: const Color(0xFFFEF6D8),
                      foreground: ChatColors.amberText,
                      fontSize: 12,
                      radius: 10,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dotClock(meetAt),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: ChatColors.ink,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      place,
                      style: const TextStyle(
                        fontSize: 16,
                        color: ChatColors.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: ChatColors.line),
          const SizedBox(height: 8),
          _bullet(
            WtsIcons.bell,
            'Pengingat dikirim H-1 dan 1 jam sebelum',
          ),
          _bullet(
            WtsIcons.clock,
            'Tombol Berangkat aktif ${slotLabel(opens)}',
          ),
          _bullet(
            WtsIcons.tag,
            'Barang berlabel Dipesan di Market',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ChatButton(
                  label: 'Ubah jadwal',
                  height: 52,
                  onTap: onChange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChatButton(
                  label: 'Berangkat',
                  filled: true,
                  height: 52,
                  enabled: departEnabled && !departed,
                  onTap: departed ? null : onDepart,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kartu "X sudah berangkat, OTW ..." dengan progres perkiraan tiba.
class TrackingCard extends StatelessWidget {
  const TrackingCard({
    super.key,
    required this.actorName,
    required this.place,
    required this.departedAt,
    this.onTap,
  });

  final String actorName;
  final String place;
  final DateTime departedAt;
  final VoidCallback? onTap;

  static const _etaMinutes = 10;

  @override
  Widget build(BuildContext context) {
    final eta = departedAt.add(const Duration(minutes: _etaMinutes));
    final elapsed = DateTime.now().difference(departedAt).inSeconds;
    final progress = (elapsed / (_etaMinutes * 60)).clamp(.08, 1.0).toDouble();
    final left = math.max(1, eta.difference(DateTime.now()).inMinutes);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFEDF3FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD3DEF8)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const AppIcon(
                    WtsIcons.send,
                    color: ChatColors.blue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$actorName sudah berangkat, OTW $place',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: ChatColors.ink,
                        ),
                      ),
                      Text(
                        'Perkiraan sampai $left menit · ${dotClock(eta)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: ChatColors.text2,
                        ),
                      ),
                    ],
                  ),
                ),
                const AppIcon(
                  WtsIcons.chevronRight,
                  color: ChatColors.hint,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(height: 7, color: const Color(0xFFCEE0FF)),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(height: 7, color: ChatColors.blue),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------- sampai & konfirmasi

/// Kartu hitung mundur 15 menit setelah saya menandai sudah sampai.
class ArrivalWaitCard extends StatefulWidget {
  const ArrivalWaitCard({
    super.key,
    required this.peerName,
    required this.arrivedAt,
    required this.onRemind,
    required this.onNoShow,
    required this.onCancel,
  });

  final String peerName;
  final DateTime arrivedAt;
  final VoidCallback onRemind;
  final VoidCallback onNoShow;
  final VoidCallback onCancel;

  @override
  State<ArrivalWaitCard> createState() => _ArrivalWaitCardState();
}

class _ArrivalWaitCardState extends State<ArrivalWaitCard> {
  static const _total = Duration(minutes: 15);
  Timer? _timer;

  DateTime get _deadline => widget.arrivedAt.add(_total);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var left = _deadline.difference(DateTime.now());
    if (left.isNegative) left = Duration.zero;
    final expired = left == Duration.zero;
    final mm = left.inMinutes.toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');
    final fraction = left.inSeconds / _total.inSeconds;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFA),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF2C94C), width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CustomPaint(
                  painter: _RingPainter(fraction: fraction),
                  child: Center(
                    child: Text(
                      '$mm.$ss',
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: ChatColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Menunggu ${widget.peerName} di titik temu',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ChatColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Hitung mundur 15 menit. Setelah habis, kamu bisa menandai dia tidak datang.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: ChatColors.text2,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ChatButton(
                  label: 'Ingatkan ${widget.peerName}',
                  height: 58,
                  radius: 14,
                  onTap: widget.onRemind,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChatButton(
                  label: expired
                      ? 'Dia tidak datang'
                      : 'Dia tidak datang aktif ${dotClock(_deadline)}',
                  height: 58,
                  radius: 14,
                  filled: expired,
                  color: ChatColors.red,
                  disabledStyle: !expired,
                  onTap: expired ? widget.onNoShow : null,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: widget.onCancel,
            style: TextButton.styleFrom(foregroundColor: ChatColors.red),
            child: const Text(
              'Batalkan transaksi',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction});

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final track = Paint()
      ..color = const Color(0xFFF1F2F5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final arc = Paint()
      ..color = ChatColors.amber
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawCircle(rect.center, arcRect.width / 2, track);
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.fraction != fraction;
}

/// Kartu aksi umum (lawan sudah sampai / konfirmasi pembayaran).
class StatusActionCard extends StatelessWidget {
  const StatusActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.onPrimary,
  });

  final WtsIcon icon;
  final String title;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: chatCardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EEFF),
                  shape: BoxShape.circle,
                ),
                child: AppIcon(icon, color: ChatColors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: ChatColors.ink,
                      ),
                    ),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 13,
                        color: ChatColors.text2,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (primaryLabel != null) ...[
            const SizedBox(height: 14),
            ChatButton(
              label: primaryLabel!,
              filled: true,
              height: 50,
              onTap: onPrimary,
            ),
          ],
        ],
      ),
    );
  }
}

/// Kartu "Transaksi selesai".
class DoneCard extends StatelessWidget {
  const DoneCard({
    super.key,
    required this.chat,
    required this.meId,
    required this.peer,
    required this.productTitle,
    required this.onProblem,
  });

  final MarketChat chat;
  final String meId;
  final AppUser peer;
  final String? productTitle;
  final VoidCallback onProblem;

  @override
  Widget build(BuildContext context) {
    final peerName = firstName(peer);
    final iAmSeller = chat.sellerId == meId;
    final peerLabel =
        iAmSeller ? '$peerName · barang diterima' : '$peerName · pembayaran diterima';
    final meLabel =
        iAmSeller ? 'Kamu · pembayaran diterima' : 'Kamu · barang diterima';

    final deadline = chat.soldAt?.add(const Duration(hours: 24));
    final left = deadline?.difference(DateTime.now());
    final canReport = left != null && !left.isNegative;
    final hint = canReport
        ? 'Laporan masalah bisa diajukan ${left.inHours >= 1 ? '${left.inHours} jam' : '${math.max(1, left.inMinutes)} menit'} lagi'
        : 'Batas waktu pengajuan laporan sudah lewat';

    Widget chip(String text) => ChatPill(
          label: text,
          icon: WtsIcons.check,
          background: ChatColors.greenBg,
          foreground: ChatColors.greenText,
          radius: 14,
          fontSize: 13,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: chatCardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFD9F3E4),
                  shape: BoxShape.circle,
                ),
                child: const AppIcon(
                  WtsIcons.check,
                  color: ChatColors.green,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transaksi selesai',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: ChatColors.ink,
                      ),
                    ),
                    Text(
                      [
                        if (chat.agreedPrice != null) chatRp(chat.agreedPrice!),
                        ?productTitle,
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: ChatColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [chip(peerLabel), chip(meLabel)],
          ),
          const SizedBox(height: 16),
          ChatButton(
            label: 'Ajukan masalah',
            height: 52,
            enabled: canReport,
            onTap: canReport ? onProblem : null,
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              hint,
              style: const TextStyle(fontSize: 12.5, color: ChatColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel pengganti kolom ketik saat obrolan terkunci.
class LockedPanel extends StatelessWidget {
  const LockedPanel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        14,
        14,
        14,
        14 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FC),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const AppIcon(
              WtsIcons.lock,
              size: 22,
              color: Color(0xFF5B6B8C),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  color: ChatColors.text2,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- chat cepat

/// Panel putih di bawah: "Chat cepat" + kolom ketik.
class MarketInputPanel extends StatefulWidget {
  const MarketInputPanel({
    super.key,
    required this.defaults,
    required this.onSend,
    required this.onAttach,
    this.reply,
    this.onCloseReply,
  });

  final List<String> defaults;
  final Future<void> Function(String text) onSend;
  final VoidCallback onAttach;
  final ReplyDraft? reply;
  final VoidCallback? onCloseReply;

  @override
  State<MarketInputPanel> createState() => _MarketInputPanelState();
}

class _MarketInputPanelState extends State<MarketInputPanel> {
  final _controller = TextEditingController();
  final List<String> _custom = [];
  bool _expanded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fill(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await widget.onSend(text);
  }

  Future<void> _addCustom() async {
    final text = await textInputDialog(
      context,
      title: 'Balasan cepat baru',
      hint: 'Tulis balasan',
      confirmLabel: 'Simpan',
      validator: (v) =>
          v.trim().isEmpty ? 'Balasan tidak boleh kosong' : null,
    );
    if (text == null || !mounted) return;
    setState(() => _custom.add(text.trim()));
  }

  Widget _chip(String text) {
    return GestureDetector(
      onTap: () => _fill(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF4FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFC9DBFF)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1D4ED8),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = [...widget.defaults, ..._custom];
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x141E3A8A),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                const AppIcon(WtsIcons.zap, size: 19, color: ChatColors.amber),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Chat cepat',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: ChatColors.ink,
                    ),
                  ),
                ),
                AppIcon(
                  _expanded
                      ? WtsIcons.chevronDown
                      : WtsIcons.chevronUp,
                  size: 28,
                  color: ChatColors.ink,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_expanded) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final t in all) _chip(t)],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _addCustom,
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(color: const Color(0xFFC9D3E6)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(WtsIcons.circlePlus,
                        size: 22, color: ChatColors.ink),
                    SizedBox(width: 6),
                    Text(
                      'Tambahkan balasan cepat',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ChatColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final t in all) ...[_chip(t), const SizedBox(width: 8)],
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (widget.reply != null)
            ReplyPreviewBar(
              draft: widget.reply!,
              onClose: widget.onCloseReply ?? () {},
            ),
          ChatInputBar(
            controller: _controller,
            onSend: _submit,
            onAttach: widget.onAttach,
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- penilaian

Future<({int stars, String? comment})?> showRatingSheet(BuildContext context) {
  return showChatSheet<({int stars, String? comment})>(
    context,
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
    return ChatSheetFrame(
      title: 'Beri penilaian',
      subtitle: 'Bagaimana pengalaman transaksimu?',
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () => setState(() => _stars = i),
                    iconSize: 38,
                    icon: AppIcon(
                      i <= _stars
                          ? WtsIcons.star
                          : WtsIcons.starBorder,
                      color: ChatColors.amber,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _comment,
              maxLines: 2,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'Ulasan singkat (opsional)',
                filled: true,
                fillColor: const Color(0xFFF4F6FB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ChatButton(
              label: 'Kirim penilaian',
              filled: true,
              height: 54,
              onTap: () {
                final c = _comment.text.trim();
                Navigator.of(context).pop(
                  (stars: _stars, comment: c.isEmpty ? null : c),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}