import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wts/core/session/session.dart';
import 'package:wts/core/theme/app_theme.dart';
import 'package:wts/core/utils/guard.dart';
import 'package:wts/features/chat/domain/chat_models.dart';
import 'package:wts/features/chat/presentation/message_widgets.dart';
import 'package:wts/features/chat/presentation/share_flows.dart';
import 'package:wts/features/chat/data/fake_dm_repository.dart';
import 'package:wts/features/chat/domain/dm.dart';
import 'package:wts/features/chat/presentation/dm_providers.dart';
import 'package:wts/shared/models/app_user.dart';
import 'package:wts/shared/widgets/common_widgets.dart';
import 'package:wts/shared/widgets/dialogs.dart';
import 'package:wts/shared/widgets/glass.dart';

class DmRoomPage extends ConsumerStatefulWidget {
  const DmRoomPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<DmRoomPage> createState() => _DmRoomPageState();
}

class _DmRoomPageState extends ConsumerState<DmRoomPage> {
  DmRepository get _repo => ref.read(dmRepositoryProvider);

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
      message: 'Kalian tidak bisa saling mengirim pesan dan konten saling disembunyikan.',
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

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final async = ref.watch(dmConversationProvider(widget.conversationId));

    ref.listen(dmConversationProvider(widget.conversationId), (prev, next) {
      final c = next.value;
      if (c != null && c.unread > 0) _repo.markRead(widget.conversationId);
    });

    return GlassScaffold(
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
                  GlassHeader(title: 'Pesan', onBack: context.pop),
                  const Expanded(
                    child: EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
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

    return Column(
      children: [
        GlassHeader(
          title: other.name,
          subtitle: other.online ? 'Sedang aktif' : '@${other.username}',
          onBack: context.pop,
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                switch (v) {
                  case 'block':
                    _block(other);
                  case 'report':
                    _report();
                  case 'sim':
                    final repo = _repo;
                    if (repo is FakeDmRepository) {
                      guarded(
                        context,
                        () => repo.simulateReply(widget.conversationId),
                      );
                    }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'report', child: Text('Laporkan')),
                const PopupMenuItem(value: 'block', child: Text('Blokir')),
                if (kDebugMode && _repo is FakeDmRepository)
                  const PopupMenuItem(
                    value: 'sim',
                    child: Text('Simulasi: dia membalas'),
                  ),
              ],
            ),
          ],
        ),
        const RetentionBanner(text: 'Pesan dihapus otomatis setelah 3 hari'),
        if (incomingRequest)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: GlassCard(
              blur: 0,
              radius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${other.name} ingin mengirim pesan kepadamu',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ini adalah permintaan pesan. Terima untuk mulai membalas.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () => guarded(
                            context,
                            () => _repo.accept(widget.conversationId),
                          ),
                          child: const Text('Terima'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await guarded(
                              context,
                              () => _repo.ignore(widget.conversationId),
                            );
                            if (mounted) context.pop();
                          },
                          child: const Text('Abaikan'),
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () => _block(other),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                        child: const Text('Blokir'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: MessageList(
            messages: conv.messages,
            meId: me.id,
            onLongPress: (m) => _deleteMessage(m, me.id),
          ),
        ),
        ChatComposer(
          enabled: disabledHint == null,
          disabledHint: disabledHint ?? '',
          onSend: (text) => _send(MessageType.text, body: text),
          actions: buildShareActions(
            context,
            (type, {body, meta}) => _send(type, body: body, meta: meta),
          ),
        ),
      ],
    );
  }
}
