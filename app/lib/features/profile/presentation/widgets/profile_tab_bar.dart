import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Tiga tab profil. Saved hanya untuk profil sendiri.
enum ProfileTab {
  posts('Postingan'),
  market('Market'),
  saved('Saved');

  const ProfileTab(this.label);

  final String label;
}

class ProfileTabBar extends StatelessWidget {
  const ProfileTabBar({
    super.key,
    required this.tabs,
    required this.current,
    required this.onChanged,
  });

  final List<ProfileTab> tabs;
  final ProfileTab current;
  final ValueChanged<ProfileTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final t in tabs)
          Semantics(
            button: true,
            selected: t == current,
            label: t.label,
            child: InkWell(
              onTap: () => onChanged(t),
              borderRadius: BorderRadius.circular(100),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: t == current
                      ? AppColors.brandBlue.withValues(alpha: 0.14)
                      : null,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  t.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: t == current
                        ? AppColors.brandBlue
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
