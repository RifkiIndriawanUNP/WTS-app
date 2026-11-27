import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/glass_sheet.dart';
import '../../domain/comment.dart';

enum CommentMenuAction { edit, delete, report }

/// Menu titik tiga pada komentar. Pemilik: ubah (5 menit) / hapus.
/// Pengguna lain: laporkan.
Future<CommentMenuAction?> showCommentMenu(
  BuildContext context,
  Comment comment,
) {
  final canEdit = comment.canEdit(DateTime.now());
  return showGlassSheet<CommentMenuAction>(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (comment.isMine) ...[
            ListTile(
              enabled: canEdit,
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Ubah komentar'),
              subtitle: Text(
                canEdit
                    ? 'Bisa diubah dalam 5 menit pertama'
                    : 'Hanya bisa dalam 5 menit setelah dikirim',
              ),
              onTap: () => Navigator.of(ctx).pop(CommentMenuAction.edit),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              title: const Text(
                'Hapus komentar',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () => Navigator.of(ctx).pop(CommentMenuAction.delete),
            ),
          ] else
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Laporkan komentar'),
              onTap: () => Navigator.of(ctx).pop(CommentMenuAction.report),
            ),
        ],
      ),
    ),
  );
}
