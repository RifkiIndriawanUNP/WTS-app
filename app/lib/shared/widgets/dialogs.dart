import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wts/core/theme/app_theme.dart';
import 'package:wts/shared/widgets/common_widgets.dart';

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Ya',
  String cancelLabel = 'Batal',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Pilih satu alasan dari daftar (laporan, pembatalan, dsb).
Future<String?> pickReasonDialog(
  BuildContext context, {
  required String title,
  required List<String> reasons,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(title),
      children: [
        for (final r in reasons)
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(r),
            child: Text(r),
          ),
      ],
    ),
  );
}

/// Dialog isian teks dengan validasi. Mengembalikan teks, atau null bila batal.
Future<String?> textInputDialog(
  BuildContext context, {
  required String title,
  String? message,
  String? hint,
  String? prefixText,
  String confirmLabel = 'Kirim',
  TextInputType keyboardType = TextInputType.text,
  List<TextInputFormatter>? formatters,
  String? Function(String value)? validator,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _TextInputDialog(
      title: title,
      message: message,
      hint: hint,
      prefixText: prefixText,
      confirmLabel: confirmLabel,
      keyboardType: keyboardType,
      formatters: formatters,
      validator: validator,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.confirmLabel,
    required this.keyboardType,
    this.message,
    this.hint,
    this.prefixText,
    this.formatters,
    this.validator,
  });

  final String title;
  final String? message;
  final String? hint;
  final String? prefixText;
  final String confirmLabel;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? formatters;
  final String? Function(String value)? validator;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    final error = widget.validator?.call(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[
            Text(
              widget.message!,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: widget.keyboardType,
            inputFormatters: widget.formatters,
            onSubmitted: (_) => _submit(),
            decoration: glassInput(
              hint: widget.hint,
              prefixText: widget.prefixText,
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
