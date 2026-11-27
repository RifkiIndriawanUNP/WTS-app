import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/glass_sheet.dart';
import '../../../moderation/domain/report.dart';
import '../../../moderation/presentation/widgets/report_sheet.dart';
import '../../data/post_repository.dart';
import '../../domain/post.dart';
import '../providers/feed_providers.dart';
import '../screens/post_form_screen.dart';
import 'post_menu_sheet.dart';

enum PostActionOutcome { none, edited, closed, deleted, reported }

typedef PostActionResult = ({PostActionOutcome outcome, Post? post});

const PostActionResult _none = (outcome: PostActionOutcome.none, post: null);

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Menu titik tiga lengkap: buka menu, konfirmasi, jalankan aksi, tampilkan
/// pesan. Dipakai Home dan Detail. [post] pada hasil = postingan terbaru
/// (untuk `edited` dan `closed`).
Future<PostActionResult> showPostActions(
  BuildContext context,
  WidgetRef ref,
  Post post,
) async {
  final action = await showPostMenu(context, post);
  if (action == null || !context.mounted) {
    return _none;
  }
  final controller = ref.read(feedControllerProvider.notifier);
  try {
    switch (action) {
      case PostMenuAction.edit:
        final updated = await Navigator.of(context).push<Post>(
          MaterialPageRoute(builder: (_) => PostFormScreen(editing: post)),
        );
        if (updated != null && context.mounted) {
          _snack(context, 'Postingan diperbarui');
          return (outcome: PostActionOutcome.edited, post: updated);
        }
      case PostMenuAction.close:
        final ok = await showGlassConfirm(
          context,
          title: 'Tandai selesai?',
          message: 'Postingan ditandai "Selesai" dan komentar ditutup.',
          confirmLabel: 'Tandai selesai',
        );
        if (ok == true) {
          final updated = await controller.closePost(post);
          if (context.mounted) {
            _snack(context, 'Postingan ditandai selesai');
          }
          return (outcome: PostActionOutcome.closed, post: updated);
        }
      case PostMenuAction.delete:
        final ok = await showGlassConfirm(
          context,
          title: 'Hapus postingan?',
          message: 'Postingan beserta komentarnya akan dihapus permanen.',
          confirmLabel: 'Hapus',
          destructive: true,
        );
        if (ok == true) {
          await controller.deletePost(post);
          if (context.mounted) {
            _snack(context, 'Postingan dihapus');
          }
          return (outcome: PostActionOutcome.deleted, post: null);
        }
      case PostMenuAction.report:
        final sent = await showReportSheet(
          context,
          target: ReportTarget.post,
          targetId: post.id,
        );
        if (sent && context.mounted) {
          showReportSentSnack(context);
          return (outcome: PostActionOutcome.reported, post: null);
        }
    }
  } on PostException catch (e) {
    if (context.mounted) {
      _snack(context, e.message);
    }
  }
  return _none;
}
