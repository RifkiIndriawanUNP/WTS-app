import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/moderation_action.dart';

/// Konfirmasi tindakan moderasi. Mengembalikan alasan (kosong untuk
/// "Abaikan") atau null bila dibatalkan.
Future<String?> showModerationActionSheet(
  BuildContext context,
  ModerationAction action,
) {
  return showGlassSheet<String>(
    context: context,
    builder: (ctx) => _ActionForm(action: action),
  );
}

class _ActionForm extends StatefulWidget {
  const _ActionForm({required this.action});

  final ModerationAction action;

  @override
  State<_ActionForm> createState() => _ActionFormState();
}

class _ActionFormState extends State<_ActionForm> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _valid =>
      !widget.action.needsReason ||
      _reason.text.trim().length >= ModerationRules.reasonMin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.action;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        Text(
          a.label,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          a.description,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (a.needsReason) ...[
          const SizedBox(height: 14),
          GlassTextArea(
            controller: _reason,
            hintText: 'Alasan (dikirim ke pemilik konten dan dicatat di audit)',
            maxLength: ModerationRules.reasonMax,
            minLines: 3,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 14),
        GlassButton(
          label: a.label,
          variant: a.destructive
              ? GlassButtonVariant.danger
              : GlassButtonVariant.primary,
          onPressed: _valid
              ? () => Navigator.of(context).pop(_reason.text.trim())
              : null,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Batal',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ),
        if (a.adminOnly)
          Text(
            'Tindakan ini tercatat atas namamu.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.neutral,
            ),
          ),
      ],
    );
  }
}
