import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import 'glass_container.dart';

/// Input banyak baris berbahan kaca, dengan penghitung karakter di kanan bawah.
class GlassTextArea extends StatefulWidget {
  const GlassTextArea({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.errorText,
    this.maxLength = 500,
    this.minLines = 5,
    this.maxLines = 10,
    this.onChanged,
    this.focusNode,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hintText;
  final String? errorText;
  final int maxLength;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  State<GlassTextArea> createState() => _GlassTextAreaState();
}

class _GlassTextAreaState extends State<GlassTextArea> {
  late final FocusNode _node = widget.focusNode ?? FocusNode();
  bool get _ownsNode => widget.focusNode == null;

  @override
  void initState() {
    super.initState();
    _node.addListener(_rebuild);
    widget.controller.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _node.removeListener(_rebuild);
    widget.controller.removeListener(_rebuild);
    if (_ownsNode) _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasError = widget.errorText != null;
    final Color? border = hasError
        ? AppColors.error
        : (_node.hasFocus ? AppColors.secondary : null);
    final length = widget.controller.text.characters.length;
    final nearLimit = length >= widget.maxLength * 0.9;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              widget.label!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        GlassContainer(
          radius: 24,
          blur: 14,
          borderColor: border,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: Column(
            children: [
              TextField(
                controller: widget.controller,
                focusNode: _node,
                enabled: widget.enabled,
                minLines: widget.minLines,
                maxLines: widget.maxLines,
                maxLength: widget.maxLength,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                onChanged: widget.onChanged,
                cursorColor: AppColors.secondary,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  filled: false,
                  isDense: true,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  hintText: widget.hintText,
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$length/${widget.maxLength}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: nearLimit
                        ? AppColors.error
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 6),
            child: Text(
              widget.errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
      ],
    );
  }
}
