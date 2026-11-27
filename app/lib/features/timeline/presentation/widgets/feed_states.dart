import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';

/// Keadaan kosong feed (belum ada postingan / tidak ada yang cocok dengan filter).
class FeedEmpty extends StatelessWidget {
  const FeedEmpty({super.key, required this.filtered, this.onReset});

  final bool filtered;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Message(
      icon: filtered ? Icons.filter_alt_off_outlined : Icons.forum_outlined,
      title: filtered
          ? 'Tidak ada postingan yang cocok'
          : 'Linimasa masih sepi',
      message: filtered
          ? 'Coba ganti tag atau filter, atau jadi yang pertama memposting.'
          : 'Jadilah yang pertama membagikan sesuatu untuk teman kampusmu.',
      action: filtered && onReset != null
          ? SizedBox(
              width: 200,
              child: GlassButton(label: 'Reset filter', onPressed: onReset),
            )
          : null,
      theme: theme,
    );
  }
}

/// Keadaan error memuat feed pertama.
class FeedError extends StatelessWidget {
  const FeedError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Message(
      icon: Icons.cloud_off_rounded,
      title: 'Linimasa gagal dimuat',
      message: message,
      action: SizedBox(
        width: 200,
        child: GlassButton(label: 'Coba lagi', onPressed: onRetry),
      ),
      theme: Theme.of(context),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    required this.theme,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final ThemeData theme;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 56, 32, 32),
      child: Column(
        children: [
          Icon(icon, size: 52, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}
