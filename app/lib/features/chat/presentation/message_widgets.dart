import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:wts/core/utils/format.dart';
import 'package:wts/features/chat/domain/chat_models.dart';
import 'package:wts/features/chat/presentation/chat_ui.dart';
import 'package:wts/features/chat/presentation/link_utils.dart';
import 'package:wts/shared/models/app_user.dart';

// ------------------------------------------------------------------ daftar

/// Daftar pesan rata atas (terbaru di bawah). Otomatis turun ke pesan terbaru
/// saat [changeToken] berubah.
class ChatListView extends StatefulWidget {
  const ChatListView({
    super.key,
    required this.children,
    required this.changeToken,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
  });

  final List<Widget> children;
  final Object changeToken;
  final EdgeInsets padding;

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _toBottom(animate: false);
  }

  @override
  void didUpdateWidget(covariant ChatListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.changeToken != widget.changeToken) _toBottom(animate: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toBottom({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final max = _controller.position.maxScrollExtent;
      if (animate) {
        _controller.animateTo(
          max,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _controller.jumpTo(max);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: _controller,
      padding: widget.padding,
      children: widget.children,
    );
  }
}

/// Chip pemisah hari ("Hari ini").
class DayChip extends StatelessWidget {
  const DayChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F1E3A8A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: ChatColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Susun item pesan + pemisah hari. [itemBuilder] boleh mengembalikan
/// beberapa widget (mis. pesan + kartu aksi) dalam satu Column.
List<Widget> buildChatItems(
  List<ChatMessage> messages,
  Widget Function(ChatMessage message) itemBuilder,
) {
  final out = <Widget>[];
  for (var i = 0; i < messages.length; i++) {
    final m = messages[i];
    if (i == 0 || !sameDay(messages[i - 1].createdAt, m.createdAt)) {
      out.add(DayChip(label: dayLabel(m.createdAt)));
    }
    out.add(itemBuilder(m));
  }
  return out;
}

// ----------------------------------------------------------------- balasan

class ReplyDraft {
  const ReplyDraft({required this.name, required this.text});

  final String name;
  final String text;
}

/// Pratinjau balasan di atas kolom ketik.
class ReplyPreviewBar extends StatelessWidget {
  const ReplyPreviewBar({super.key, required this.draft, required this.onClose});

  final ReplyDraft draft;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: ChatColors.blueSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: ChatColors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ChatColors.blue,
                  ),
                ),
                Text(
                  draft.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: ChatColors.text2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: ChatColors.muted,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Aksi pada pesan (tekan lama): 'reply' / 'delete'.
Future<String?> showMessageActions(
  BuildContext context, {
  required bool canDelete,
}) {
  return showChatSheet<String>(
    context,
    builder: (ctx) => ChatSheetFrame(
      showClose: false,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionRow(
            icon: Icons.reply_rounded,
            label: 'Balas',
            onTap: () => Navigator.of(ctx).pop('reply'),
          ),
          if (canDelete)
            _ActionRow(
              icon: Icons.delete_outline_rounded,
              label: 'Hapus untuk semua orang',
              color: ChatColors.red,
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
        ],
      ),
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = ChatColors.ink,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ bubble

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.meId,
    this.market = false,
    this.onLongPress,
  });

  final ChatMessage message;
  final String meId;

  /// Gaya chat market: avatar di sisi bubble, bubble saya berbingkai.
  final bool market;
  final VoidCallback? onLongPress;

  bool get _mine => message.senderId == meId;

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m.isSystem) return SystemChip(message: m, meId: meId);

    final mine = _mine;
    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: m.type == MessageType.image
          ? _ImageBubble(message: m)
          : _TextBubble(message: m, mine: mine, market: market),
    );

    if (!market) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: bubble,
        ),
      );
    }

    final avatar = ChatAvatar(user: userById(m.senderId ?? ''), size: 44);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: mine
            ? [Flexible(child: bubble), const SizedBox(width: 8), avatar]
            : [avatar, const SizedBox(width: 8), Flexible(child: bubble)],
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.time,
    required this.color,
    required this.showTicks,
    required this.read,
    required this.readColor,
  });

  final DateTime time;
  final Color color;
  final bool showTicks;
  final bool read;
  final Color readColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          dotClock(time),
          style: TextStyle(fontSize: 11.5, color: color, height: 1.2),
        ),
        if (showTicks) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.done_all_rounded,
            size: 16,
            color: read ? readColor : color,
          ),
        ],
      ],
    );
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({
    required this.message,
    required this.mine,
    required this.market,
  });

  final ChatMessage message;
  final bool mine;
  final bool market;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final solid = mine && !market; // DM: bubble saya biru penuh.
    final fg = solid ? Colors.white : (mine ? ChatColors.text2 : ChatColors.ink);
    final sub = solid
        ? Colors.white.withValues(alpha: .78)
        : (mine ? const Color(0xFF7C879B) : ChatColors.muted);
    final tickRead = solid ? Colors.white : ChatColors.blue;

    final Color fill;
    Border? border;
    if (solid) {
      fill = ChatColors.mine;
    } else if (mine) {
      fill = const Color(0xFFFAFBFD);
      border = Border.all(color: const Color(0xFFC8CEDD), width: 1.5);
    } else {
      fill = Colors.white;
    }

    final stamp = _Stamp(
      time: m.createdAt,
      color: sub,
      showTicks: mine,
      read: m.readByOther,
      readColor: tickRead,
    );

    final replyText = m.meta['replyText'] as String?;
    final replyName = m.meta['replyName'] as String?;

    final Widget body;
    if (m.type == MessageType.text) {
      body = Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 10,
        runSpacing: 2,
        children: [
          Linkify(
            text: m.body ?? '',
            style: TextStyle(color: fg, fontSize: 15.5, height: 1.35),
            linkStyle: TextStyle(
              color: solid ? Colors.white : ChatColors.blue,
              decoration: TextDecoration.underline,
            ),
            onOpen: (link) => confirmAndOpenLink(context, link.url),
          ),
          stamp,
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _special(context, fg),
          ),
          const SizedBox(height: 4),
          stamp,
        ],
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .74,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 9),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        border: border,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (replyText != null)
            _Quote(
              name: replyName ?? '',
              text: replyText,
              onSolid: solid,
            ),
          body,
        ],
      ),
    );
  }

  Widget _special(BuildContext context, Color fg) {
    final m = message;
    switch (m.type) {
      case MessageType.link:
        final url = m.body ?? '';
        return InkWell(
          onTap: () => confirmAndOpenLink(context, url),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_rounded, color: fg, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  url,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        );
      case MessageType.location:
        final lat = (m.meta['lat'] as num?)?.toDouble() ?? 0;
        final lng = (m.meta['lng'] as num?)?.toDouble() ?? 0;
        return InkWell(
          onTap: () => openMaps(lat, lng),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on_rounded, color: fg),
                  const SizedBox(width: 6),
                  Text(
                    'Lokasi dibagikan',
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                style: TextStyle(color: fg.withValues(alpha: .8), fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                'Buka di Google Maps',
                style: TextStyle(
                  color: fg,
                  fontSize: 12.5,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        );
      case MessageType.contact:
        final phone = (m.meta['phone'] as String?) ?? '';
        return InkWell(
          onTap: () => openWhatsApp(phone),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone_in_talk_outlined, color: fg),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hubungi via WhatsApp',
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    phone,
                    style: TextStyle(
                      color: fg.withValues(alpha: .85),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      case MessageType.text:
      case MessageType.image:
      case MessageType.offer:
      case MessageType.system:
        return const SizedBox.shrink();
    }
  }
}

/// Kutipan balasan di dalam bubble.
class _Quote extends StatelessWidget {
  const _Quote({required this.name, required this.text, required this.onSolid});

  final String name;
  final String text;
  final bool onSolid;

  @override
  Widget build(BuildContext context) {
    final bar = onSolid ? Colors.white : ChatColors.blue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: onSolid
            ? Colors.white.withValues(alpha: .16)
            : ChatColors.blueSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: bar, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: onSolid ? Colors.white : ChatColors.blue,
            ),
          ),
          Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: onSolid
                  ? Colors.white.withValues(alpha: .88)
                  : ChatColors.text2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageBubble extends StatelessWidget {
  const _ImageBubble({required this.message});

  final ChatMessage message;

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFE3EAFF),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 44,
        color: Color(0xFF5B7FEA),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = message.meta['imagePath'] as String?;
    final Widget image = (path == null || path.isEmpty)
        ? _placeholder()
        : Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _placeholder(),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        width: 210,
        height: 175,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xE6888C99),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  dotClock(message.createdAt),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Indikator "sedang mengetik" (tiga titik).
class TypingBubble extends StatelessWidget {
  const TypingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 64,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: const BoxDecoration(
                    color: Color(0xFF8A97B5),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- pesan sistem

/// Chip pesan sistem (sepakat, sampai, dsb). Teks disusun dari meta agar
/// "Kamu"/nama menyesuaikan sudut pandang pembaca.
class SystemChip extends StatelessWidget {
  const SystemChip({super.key, required this.message, required this.meId});

  final ChatMessage message;
  final String meId;

  String _who(String? id) =>
      id == meId ? 'Kamu' : firstName(userById(id ?? ''));

  /// null = sembunyikan.
  String? _text() {
    final meta = message.meta;
    final kind = meta['kind'];
    final time = dotClock(message.createdAt);
    switch (kind) {
      case 'agreed':
        final price = meta['price'] as int?;
        final at = meta['meetAt'] as int?;
        final when = at == null ? null : DateTime.fromMillisecondsSinceEpoch(at);
        return [
          'Sepakat 2/2',
          if (price != null) formatRp(price),
          if (when != null) '${dayShort(when)} · ${dotClock(when)}',
        ].join(' · ');
      case 'arrived':
        return '${_who(meta['actor'] as String?)} menandai sudah sampai · $time';
      case 'departed':
        return '${_who(meta['actor'] as String?)} berangkat · $time';
      case 'sold':
        return 'Kedua pihak konfirmasi · $time';
      case 'rescheduled':
        final at = meta['meetAt'] as int?;
        final when = at == null ? null : DateTime.fromMillisecondsSinceEpoch(at);
        return when == null
            ? 'Jadwal diubah'
            : 'Jadwal diubah · ${dayShort(when)} · ${dotClock(when)}';
      case 'rejected':
        return null;
      default:
        return message.body ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _text();
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final kind = message.meta['kind'];
    IconData? icon;
    Color iconColor = ChatColors.text2;
    if (kind == 'arrived') {
      icon = Icons.location_on_rounded;
      iconColor = ChatColors.red;
    } else if (kind == 'sold') {
      icon = Icons.check_rounded;
      iconColor = ChatColors.green;
    } else if (kind == 'agreed' || kind == 'rescheduled') {
      icon = Icons.check_rounded;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FD),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3E8F3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ChatColors.text2,
                    fontWeight: FontWeight.w500,
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

// ------------------------------------------------------------- kolom ketik

class ComposerAction {
  const ComposerAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// Kolom ketik: [+] [Tambah komentar...] [kirim].
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttach,
    this.enabled = true,
    this.hint = 'Tambah komentar...',
  });

  final TextEditingController controller;
  final Future<void> Function() onSend;
  final VoidCallback onAttach;
  final bool enabled;
  final String hint;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant ChatInputBar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      _onChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText && mounted) setState(() => _hasText = has);
  }

  @override
  Widget build(BuildContext context) {
    final canSend = widget.enabled && _hasText;
    return Container(
      height: 56,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDCE2EF)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.enabled ? widget.onAttach : null,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD5DAE5)),
              ),
              child: Icon(
                Icons.add_rounded,
                size: 26,
                color: widget.enabled ? ChatColors.ink : ChatColors.hint,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: widget.controller,
              enabled: widget.enabled,
              minLines: 1,
              maxLines: 1,
              inputFormatters: [LengthLimitingTextInputFormatter(2000)],
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                if (canSend) widget.onSend();
              },
              style: const TextStyle(fontSize: 15, color: ChatColors.ink),
              decoration: InputDecoration.collapsed(
                hintText: widget.hint,
                hintStyle: const TextStyle(
                  fontSize: 14.5,
                  color: ChatColors.hint,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: canSend ? widget.onSend : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: canSend ? ChatColors.blue : const Color(0xFFEEF0F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_outlined,
                size: 22,
                color: canSend ? Colors.white : const Color(0xFF7C879B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- lampiran (+)

/// Sheet lampiran: tombol kamera + galeri terbaru. Bila [recentPhotos]
/// kosong, galeri diganti ubin aksi (Foto, Lokasi, Kontak WA, Tautan, Tawar).
///
/// Untuk menampilkan grid foto galeri seperti desain, isi [recentPhotos]
/// dengan path file foto (mis. dari paket photo_manager) dan [onPhoto].
Future<void> showAttachSheet(
  BuildContext context, {
  required List<ComposerAction> actions,
  VoidCallback? onCamera,
  List<String> recentPhotos = const [],
  ValueChanged<String>? onPhoto,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ChatThemed(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          top: 12,
          bottom: MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFC9D1E0),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 18),
            Material(
              color: ChatColors.blue,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onCamera == null
                    ? null
                    : () {
                        Navigator.of(ctx).pop();
                        onCamera();
                      },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_camera_rounded,
                          color: Colors.white, size: 26),
                      SizedBox(width: 10),
                      Text(
                        'Izinkan akses ke kamera',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (recentPhotos.isNotEmpty)
              Flexible(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  child: GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (final path in recentPhotos)
                        GestureDetector(
                          onTap: () {
                            Navigator.of(ctx).pop();
                            onPhoto?.call(path);
                          },
                          child: Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                Container(color: const Color(0xFFE3EAFF)),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final a in actions)
                      GestureDetector(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          a.onTap();
                        },
                        child: Container(
                          width: 100,
                          height: 92,
                          decoration: BoxDecoration(
                            color: ChatColors.blueTint,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(a.icon, size: 28, color: ChatColors.blue),
                              const SizedBox(height: 8),
                              Text(
                                a.label,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: ChatColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Nama pendek pengirim untuk kutipan balasan.
String replyNameFor(ChatMessage m, String meId) =>
    m.senderId == meId ? 'Kamu' : firstName(userById(m.senderId ?? ''));

/// Pembantu: AppUser pengirim (untuk tampilan).
AppUser senderOf(ChatMessage m) => userById(m.senderId ?? '');