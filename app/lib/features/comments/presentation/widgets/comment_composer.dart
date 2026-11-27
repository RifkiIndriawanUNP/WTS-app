import 'package:flutter/material.dart';

import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../domain/comment.dart';

/// Bilah tulis komentar di dasar layar detail. Menampung mode balas / ubah
/// (chip di atas input) dan keadaan "komentar ditutup".
class CommentComposer extends StatelessWidget {
  const CommentComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.initials,
    this.avatarPath,
    this.closed = false,
    this.sending = false,
    this.replyingTo,
    this.editing = false,
    required this.onSend,
    required this.onCancelMode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String initials;
  final String? avatarPath;
  final bool closed;
  final bool sending;

  /// Nama yang sedang dibalas (null = komentar utama).
  final String? replyingTo;
  final bool editing;
  final VoidCallback onSend;
  final VoidCallback onCancelMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modeLabel = editing
        ? 'Mengubah komentar'
        : (replyingTo != null ? 'Membalas $replyingTo' : null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: GlassContainer(
        radius: 24,
        blur: 14,
        shadow: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          child: closed
              ? Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Komentar ditutup',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (modeLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              editing
                                  ? Icons.edit_outlined
                                  : Icons.reply_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                modeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            InkResponse(
                              onTap: onCancelMode,
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.close_rounded, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: UserAvatar(
                            initials: initials,
                            imagePath: avatarPath,
                            size: 30,
                            glass: false,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            enabled: !sending,
                            minLines: 1,
                            maxLines: 5,
                            maxLength: CommentRules.bodyMax,
                            textCapitalization: TextCapitalization.sentences,
                            keyboardType: TextInputType.multiline,
                            buildCounter:
                                (
                                  context, {
                                  required currentLength,
                                  required isFocused,
                                  required maxLength,
                                }) => currentLength >= (maxLength ?? 0) - 100
                                ? Text('$currentLength/$maxLength')
                                : null,
                            decoration: const InputDecoration(
                              hintText: 'Tambah komentar...',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: controller,
                          builder: (context, value, _) {
                            final ok =
                                CommentRules.validateBody(value.text) == null;
                            return IconButton(
                              onPressed: ok && !sending ? onSend : null,
                              tooltip: editing
                                  ? 'Simpan perubahan'
                                  : 'Kirim komentar',
                              icon: sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      editing
                                          ? Icons.check_rounded
                                          : Icons.send_rounded,
                                    ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
