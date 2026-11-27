import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../domain/post_filter.dart';

/// Lembar filter Home. Mengembalikan filter baru ("Terapkan" / "Reset"),
/// atau null bila ditutup tanpa menerapkan.
Future<PostFilter?> showPostFilterSheet(
  BuildContext context,
  PostFilter current,
) {
  return showGlassSheet<PostFilter>(
    context: context,
    builder: (ctx) => _FilterSheet(initial: current),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final PostFilter initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late PostFilter _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Filter postingan',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: _draft.isActive
                    ? () => setState(() => _draft = const PostFilter())
                    : null,
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Waktu terbit',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in PostTimeRange.values)
                GlassChip(
                  label: r.label,
                  selected: _draft.range == r,
                  onTap: () =>
                      setState(() => _draft = _draft.copyWith(range: r)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hanya yang ada gambar'),
            value: _draft.onlyWithImages,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(onlyWithImages: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sembunyikan yang sudah selesai'),
            subtitle: const Text(
              'Postingan yang ditandai "Selesai" oleh penulisnya',
            ),
            value: _draft.hideClosed,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(hideClosed: v)),
          ),
          const SizedBox(height: 12),
          GlassButton(
            label: _draft.isActive
                ? 'Terapkan (${_draft.activeCount})'
                : 'Terapkan',
            onPressed: () => Navigator.of(context).pop(_draft),
          ),
        ],
      ),
    );
  }
}
