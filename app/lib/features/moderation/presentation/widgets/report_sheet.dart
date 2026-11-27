import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_sheet.dart';
import '../../../../shared/widgets/glass_text_area.dart';
import '../../data/report_repository.dart';
import '../../domain/report.dart';
import '../providers/report_providers.dart';

/// Lembar "Laporkan". Mengembalikan true bila laporan terkirim.
/// Setelah itu tampilkan pesan terima kasih (lihat [showReportSentSnack]).
Future<bool> showReportSheet(
  BuildContext context, {
  required ReportTarget target,
  required String targetId,
}) async {
  final sent = await showGlassSheet<bool>(
    context: context,
    builder: (ctx) => _ReportForm(target: target, targetId: targetId),
  );
  return sent ?? false;
}

void showReportSentSnack(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('Terima kasih. Laporanmu akan ditinjau moderator.'),
      ),
    );
}

class _ReportForm extends ConsumerStatefulWidget {
  const _ReportForm({required this.target, required this.targetId});

  final ReportTarget target;
  final String targetId;

  @override
  ConsumerState<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends ConsumerState<_ReportForm> {
  final TextEditingController _note = TextEditingController();
  ReportReason? _reason;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _sending) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(reportRepositoryProvider)
          .submit(
            target: widget.target,
            targetId: widget.targetId,
            reason: reason,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ReportException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        Text(
          'Laporkan ${widget.target.label}',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pilih alasan yang paling sesuai. Identitasmu tidak ditampilkan ke pemilik konten.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final r in ReportReason.values)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            onTap: _sending ? null : () => setState(() => _reason = r),
            leading: Icon(
              _reason == r
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: _reason == r ? AppColors.brandBlue : null,
            ),
            title: Text(r.label),
          ),
        const SizedBox(height: 8),
        GlassTextArea(
          controller: _note,
          hintText: 'Catatan tambahan (opsional)',
          maxLength: ReportRules.noteMax,
          minLines: 2,
          maxLines: 4,
          enabled: !_sending,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        const SizedBox(height: 14),
        GlassButton(
          label: 'Kirim laporan',
          loading: _sending,
          onPressed: _reason == null ? null : _submit,
        ),
      ],
    );
  }
}
