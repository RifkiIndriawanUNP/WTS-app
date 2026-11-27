import 'package:flutter/material.dart';

import '../../../../shared/widgets/glass_sheet.dart';
import '../../domain/legal_texts.dart';

/// Lembar bawah berisi Syarat & Ketentuan / Aturan Komunitas.
Future<void> showLegalSheet(
  BuildContext context, {
  required String title,
  required List<LegalSection> sections,
}) {
  return showGlassSheet<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.75,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ringkasan draf; dokumen resmi menyusul sebelum rilis kampus.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final (heading, body) in sections) ...[
              Text(
                heading,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      );
    },
  );
}
