import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:wts/core/theme/app_theme.dart';
import 'package:wts/core/utils/format.dart';
import 'package:wts/features/chat/domain/chat_models.dart';
import 'package:wts/features/chat/presentation/link_utils.dart';
import 'package:wts/shared/widgets/common_widgets.dart';
import 'package:wts/shared/widgets/glass.dart';

/// Daftar pesan (terbaru di bawah) dengan pemisah hari.
class MessageList extends StatelessWidget {
  const MessageList({
    super.key,
    required this.messages,
    required this.meId,
    this.offerBuilder,
    this.onLongPress,
  });

  final List<ChatMessage> messages;
  final String meId;
  final Widget Function(BuildContext context, ChatMessage message)?
      offerBuilder;
  final void Function(ChatMessage message)? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Belum ada pesan',
        message: 'Mulai percakapan dengan menyapa.',
      );
    }
    final reversed = messages.reversed.toList();
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      itemCount: reversed.length,
      itemBuilder: (context, i) {
        final m = reversed[i];
        final earlier = i + 1 < reversed.length ? reversed[i + 1] : null;
        final showDay = earlier == null || !sameDay(earlier.createdAt, m.createdAt);
        return Column(
          children: [
            if (showDay) _DayChip(label: dayLabel(m.createdAt)),
            MessageBubble(
              message: m,
              mine: m.senderId == meId,
              offerWidget: m.type == MessageType.offer
                  ? offerBuilder?.call(context, m)
                  : null,
              onLongPress: onLongPress == null ? null : () => onLongPress!(m),
            ),
          ],
        );
      },
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    this.offerWidget,
    this.onLongPress,
  });

  final ChatMessage message;
  final bool mine;
  final Widget? offerWidget;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              m.body ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    if (m.type == MessageType.offer) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: offerWidget ?? const SizedBox.shrink(),
          ),
        ),
      );
    }

    final fg = mine ? Colors.white : AppColors.ink;
    final maxWidth = MediaQuery.sizeOf(context).width * .75;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onLongPress: onLongPress,
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: mine
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: .88),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mine ? 18 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 18),
                  ),
                ),
                child: _content(context, fg),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    clock(m.createdAt),
                    style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.done_all_rounded,
                      size: 14,
                      color: m.readByOther ? AppColors.primary : AppColors.muted,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, Color fg) {
    final m = message;
    switch (m.type) {
      case MessageType.text:
        return Linkify(
          text: m.body ?? '',
          style: TextStyle(color: fg, fontSize: 15, height: 1.3),
          linkStyle: TextStyle(
            color: mine ? Colors.white : AppColors.primary,
            decoration: TextDecoration.underline,
          ),
          onOpen: (link) => confirmAndOpenLink(context, link.url),
        );
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
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        );
      case MessageType.image:
      final imagePath = m.meta['imagePath'] as String?;
      if (imagePath == null || imagePath.isEmpty) {
        return const SizedBox(
          width: 20,
          height: 150,
          child: Icon(Icons.broken_image_outlined),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(imagePath),
          width: 200,
          height: 150,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox(
            width: 200,
            height: 150,
            child: Icon(Icons.broken_image_outlined),
          ),
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
                    style: TextStyle(color: fg, fontWeight: FontWeight.w700),
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
                  fontSize: 12,
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
              Icon(Icons.phone_in_talk_rounded, color: fg),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hubungi via WhatsApp',
                    style: TextStyle(color: fg, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    phone,
                    style: TextStyle(color: fg.withValues(alpha: .85), fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        );
      case MessageType.offer:
      case MessageType.system:
        return const SizedBox.shrink();
    }
  }
}

/// Spanduk retensi / peringatan di bawah header ruang chat.
class RetentionBanner extends StatelessWidget {
  const RetentionBanner({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon ?? Icons.timer_outlined,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11.5, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

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

/// Kolom ketik pesan + baris aksi cepat (tawar, foto, lokasi, kontak, tautan).
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    this.actions = const [],
    this.enabled = true,
    this.disabledHint = 'Chat tidak aktif',
  });

  final Future<void> Function(String text) onSend;
  final List<ComposerAction> actions;
  final bool enabled;
  final String disabledHint;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() => _hasText = false);
    await widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return GlassCard(
      radius: 0,
      blur: 20,
      opacity: .78,
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.enabled && widget.actions.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final a in widget.actions)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 6),
                      child: GlassChip(
                        label: a.label,
                        icon: a.icon,
                        selected: false,
                        onTap: a.onTap,
                      ),
                    ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: widget.enabled,
                  minLines: 1,
                  maxLines: 4,
                  inputFormatters: [LengthLimitingTextInputFormatter(2000)],
                  onChanged: (v) => setState(() => _hasText = v.trim().isNotEmpty),
                  decoration: glassInput(
                    hint: widget.enabled
                        ? 'Tulis pesan...'
                        : widget.disabledHint,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: widget.enabled && _hasText ? _send : null,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
