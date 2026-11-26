import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wts/core/session/session.dart';
import 'package:wts/core/utils/guard.dart';
import 'package:wts/features/chat/data/fake_dm_repository.dart';
import 'package:wts/features/chat/domain/chat_models.dart';
import 'package:wts/features/chat/domain/dm.dart';
import 'package:wts/features/chat/presentation/chat_ui.dart';
import 'package:wts/features/chat/presentation/dm_providers.dart';
import 'package:wts/features/chat/presentation/message_widgets.dart';
import 'package:wts/features/chat/presentation/share_flows.dart';
import 'package:wts/shared/models/app_user.dart';
import 'package:wts/shared/widgets/app_icons.dart';
import 'package:wts/shared/widgets/common_widgets.dart';
import 'package:wts/shared/widgets/dialogs.dart';

class DmRoomPage extends ConsumerStatefulWidget {
  const DmRoomPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<DmRoomPage> createState() => _DmRoomPageState();
}

class _DmRoomPageState extends ConsumerState<DmRoomPage> {
  final _controller = TextEditingController();
  ReplyDraft? _reply;

  DmRepository get _repo => ref.read(dmRepositoryProvider);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(
    MessageType type, {
    String? body,
    Map<String, Object?>? meta,
  }) async {
    await guarded(
      context,
      () => _repo.send(
        widget.conversationId,
        type,
        body: body,
        meta: meta ?? const {},
      ),
    );
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final reply = _reply;
    _controller.clear();
    setState(() => _reply = null);
    await _send(
      MessageType.text,
      body: text,
      meta: reply == null
          ? null
          : {'replyName': reply.name, 'replyText': reply.text},
    );
  }

  Future<void> _onLongPress(ChatMessage m, String meId) async {
    if (m.isSystem) return;
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
    if (m.senderId != meId) return;
    final ok = await confirmDialog(
      context,
      title: 'Hapus pesan?',
      message: 'Pesan dihapus untuk semua orang (maks. 15 menit setelah dikirim).',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await guarded(
      context,
      () => _repo.deleteMessage(widget.conversationId, m.id),
    );
  }

  Future<void> _block(AppUser other) async {
    final ok = await confirmDialog(
      context,
      title: 'Blokir ${other.name}?',
      message:
          'Kalian tidak bisa saling mengirim pesan dan konten saling disembunyikan.',
      confirmLabel: 'Blokir',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await guarded(context, () => _repo.block(widget.conversationId));
    if (mounted) context.pop();
  }

  Future<void> _report() async {
    final reason = await pickReasonDialog(
      context,
      title: 'Laporkan pengguna',
      reasons: const [
        'Spam',
        'Pelecehan / perundungan',
        'Penipuan',
        'Konten dewasa',
        'Lainnya',
      ],
    );
    if (reason != null && mounted) {
      showSnack(context, 'Laporan terkirim (simulasi): $reason');
    }
  }

  void _attach() {
    Future<void> send(MessageType type, {String? body, Map<String, Object?>? meta}) =>
        _send(type, body: body, meta: meta);
    showAttachSheet(
      context,
      actions: buildShareActions(context, send),
      onCamera: () => sharePhoto(context, send, camera: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final async = ref.watch(dmConversationProvider(widget.conversationId));

    ref.listen(dmConversationProvider(widget.conversationId), (prev, next) {
      final c = next.value;
      if (c != null && c.unread > 0) _repo.markRead(widget.conversationId);
    });

    return ChatScaffold(
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            onRetry: () =>
                ref.invalidate(dmConversationProvider(widget.conversationId)),
          ),
          data: (conv) {
            if (conv == null) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ChatCircleButton(
                        icon: WtsIcons.chevronLeft,
                        iconSize: 30,
                        onTap: context.pop,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: EmptyState(
                      icon: WtsIcons.chat,
                      title: 'Percakapan tidak tersedia',
                    ),
                  ),
                ],
              );
            }
            if (conv.unread > 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _repo.markRead(widget.conversationId);
              });
            }
            return _room(conv, me);
          },
        ),
      ),
    );
  }

  Widget _menu(AppUser other) {
    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      onSelected: (v) {
        switch (v) {
          case 'info':
            showSnack(context, 'Pesan dihapus otomatis setelah 3 hari.');
          case 'block':
            _block(other);
          case 'report':
            _report();
          case 'sim':
            final repo = _repo;
            if (repo is FakeDmRepository) {
              guarded(context, () => repo.simulateReply(widget.conversationId));
            }
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'info', child: Text('Info pesan')),
        const PopupMenuItem(value: 'report', child: Text('Laporkan')),
        const PopupMenuItem(value: 'block', child: Text('Blokir')),
        if (kDebugMode && _repo is FakeDmRepository)
          const PopupMenuItem(
            value: 'sim',
            child: Text('Simulasi: dia membalas'),
          ),
      ],
      child: const ChatCircle(icon: WtsIcons.moreVert),
    );
  }

  Widget _room(DmConversation conv, AppUser me) {
    final other = userById(conv.otherId);
    final incomingRequest =
        conv.status == DmStatus.request && conv.requesterId != me.id;
    final waitingApproval = conv.status == DmStatus.request &&
        conv.requesterId == me.id &&
        conv.messages.any((m) => m.senderId == me.id);

    String? disabledHint;
    if (incomingRequest) disabledHint = 'Terima permintaan untuk membalas';
    if (waitingApproval) disabledHint = 'Menunggu persetujuan penerima';

    final items = <Widget>[
      if (incomingRequest) _requestCard(other),
      ...buildChatItems(
        conv.messages,
        (m) => MessageBubble(
          message: m,
          meId: me.id,
          onLongPress: () => _onLongPress(m, me.id),
        ),
      ),
      if (conv.peerTyping) const TypingBubble(),
    ];

    return Column(
      children: [
        ChatRoomHeader(
          user: other,
          subtitle: other.online ? 'Sedang aktif' : '@${other.username}',
          subtitleColor:
              other.online ? ChatColors.activeGreen : ChatColors.muted,
          onBack: context.pop,
          menu: _menu(other),
        ),
        Expanded(
          child: ChatListView(
            changeToken: Object.hash(conv.messages.length, conv.peerTyping),
            children: items,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_reply != null)
                ReplyPreviewBar(
                  draft: _reply!,
                  onClose: () => setState(() => _reply = null),
                ),
              ChatInputBar(
                controller: _controller,
                enabled: disabledHint == null,
                hint: disabledHint ?? 'Tambah komentar...',
                onSend: _sendText,
                onAttach: _attach,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _requestCard(AppUser other) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: chatCardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${other.name} ingin mengirim pesan kepadamu',
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: ChatColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ini adalah permintaan pesan. Terima untuk mulai membalas.',
            style: TextStyle(fontSize: 13, color: ChatColors.muted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ChatButton(
                  label: 'Terima',
                  filled: true,
                  height: 44,
                  onTap: () => guarded(
                    context,
                    () => _repo.accept(widget.conversationId),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChatButton(
                  label: 'Abaikan',
                  height: 44,
                  onTap: () async {
                    await guarded(
                      context,
                      () => _repo.ignore(widget.conversationId),
                    );
                    if (mounted) context.pop();
                  },
                ),
              ),
              TextButton(
                onPressed: () => _block(other),
                style: TextButton.styleFrom(foregroundColor: ChatColors.red),
                child: const Text('Blokir'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}