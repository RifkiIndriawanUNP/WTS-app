import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../domain/public_profile.dart';

/// Kepala profil (mengikuti desain): avatar besar, nama, tiga aksi (khusus
/// profil sendiri), lalu baris info Jurusan dan Bio.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.profile,
    required this.isOwn,
    this.onSetPhoto,
    this.onEditInfo,
    this.onSettings,
  });

  final PublicProfile profile;
  final bool isOwn;
  final VoidCallback? onSetPhoto;
  final VoidCallback? onEditInfo;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final joined = profile.joinedAt;

    return Column(
      children: [
        const SizedBox(height: 8),
        UserAvatar(
          initials: profile.initials,
          imagePath: profile.avatarPath,
          size: 104,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                '@${profile.username}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (profile.isOfficial) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.verified_rounded,
                size: 18,
                color: AppColors.brandBlue,
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Bergabung ${Fmt.date(joined)}',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        if (isOwn) ...[
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Action(
                icon: Icons.photo_camera_outlined,
                label: 'Set Photo',
                onTap: onSetPhoto,
              ),
              _Action(
                icon: Icons.edit_outlined,
                label: 'Edit Info',
                onTap: onEditInfo,
              ),
              _Action(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: onSettings,
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        _InfoRow(
          title: profile.prodiName ?? 'Belum diisi',
          label: 'Jurusan',
          dim: profile.prodiName == null,
        ),
        if (profile.bio != null && profile.bio!.trim().isNotEmpty)
          _InfoRow(title: profile.bio!, label: 'Bio'),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.label, this.dim = false});

  final String title;
  final String label;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: dim ? muted : null,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
