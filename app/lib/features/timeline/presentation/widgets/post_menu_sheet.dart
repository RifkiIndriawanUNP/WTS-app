import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/glass_sheet.dart';
import '../../domain/post.dart';

enum PostMenuAction { edit, close, delete, report }

/// Menu titik tiga pada postingan. Pemilik: tandai selesai / hapus.
/// Pengguna lain: laporkan. Mengembalikan null bila ditutup.
Future<PostMenuAction?> showPostMenu(BuildContext context, Post post) {
  return showGlassSheet<PostMenuAction>(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (post.isMine) ...[
            ListTile(
              enabled: post.canEdit(DateTime.now()),
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Ubah postingan'),
              subtitle: Text(
                post.canEdit(DateTime.now())
                    ? 'Hanya isi tulisan, dalam 24 jam pertama'
                    : 'Hanya bisa dalam 24 jam setelah diposting',
              ),
              onTap: () => Navigator.of(ctx).pop(PostMenuAction.edit),
            ),
            if (!post.isClosed)
              ListTile(
                leading: const Icon(Icons.check_circle_outline_rounded),
                title: const Text('Tandai selesai'),
                subtitle: const Text('Komentar ditutup, ditandai "Selesai"'),
                onTap: () => Navigator.of(ctx).pop(PostMenuAction.close),
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              title: const Text(
                'Hapus postingan',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () => Navigator.of(ctx).pop(PostMenuAction.delete),
            ),
          ] else
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Laporkan postingan'),
              onTap: () => Navigator.of(ctx).pop(PostMenuAction.report),
            ),
        ],
      ),
    ),
  );
}
