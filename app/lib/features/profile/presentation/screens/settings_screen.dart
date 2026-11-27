import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/auth_routes.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/legal_texts.dart';
import '../../../auth/domain/user_profile.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/legal_sheet.dart';
import '../../../comments/data/fake_comment_repository.dart';
import '../../../comments/presentation/providers/comment_providers.dart';
import '../../../moderation/presentation/providers/report_providers.dart';
import '../../../moderation/presentation/screens/report_queue_screen.dart';
import '../../../timeline/data/fake_post_repository.dart';
import '../../../timeline/presentation/providers/feed_providers.dart';
import 'edit_profile_screen.dart';

/// Versi tampilan (preview). Saat integrasi, ganti dengan package_info_plus.
const String kAppVersionLabel = '0.1.0 (preview)';

/// Pengaturan akun: info akun, ubah profil, aturan, keluar, hapus akun.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit(BuildContext context) async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
    if (saved == true && context.mounted) {
      _snack(context, 'Profil diperbarui');
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showGlassConfirm(
      context,
      title: 'Keluar dari WTS?',
      message: 'Kamu perlu masuk lagi dengan email kampus.',
      confirmLabel: 'Keluar',
      destructive: true,
    );
    if (ok != true || !context.mounted) {
      return;
    }
    await ref.read(authControllerProvider.notifier).signOut();
    ref.invalidate(
      feedControllerProvider,
    ); // daftar Home tidak boleh terbawa ke sesi lain
    if (context.mounted) {
      context.go(AuthRoutes.login);
    }
  }

  Future<void> _deleteAccount(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
  ) async {
    final confirmed = await showGlassSheet<bool>(
      context: context,
      builder: (ctx) => _DeleteAccountSheet(username: user.username),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
      // Repo palsu menyimpan data di memori; bersihkan seperti cascade di server.
      final posts = ref.read(postRepositoryProvider);
      if (posts is FakePostRepository) {
        posts.purgeCurrentUserData();
      }
      final comments = ref.read(commentRepositoryProvider);
      if (comments is FakeCommentRepository) {
        comments.purgeOwnComments();
      }
      ref.invalidate(feedControllerProvider);
      if (context.mounted) {
        context.go(AuthRoutes.login);
      }
    } on AuthException catch (e) {
      if (context.mounted) {
        _snack(context, e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider.select((s) => s.user));

    return GlassScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Kembali',
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Text(
                    'Pengaturan',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: user == null
                  ? const Center(child: Text('Silakan masuk dulu'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        const _SectionLabel('Akun'),
                        _Card(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.mail_outline_rounded),
                              title: Text(user.email),
                              subtitle: const Text(
                                'Email kampus (tidak tampil ke pengguna lain)',
                              ),
                            ),
                            if (user.isModerator)
                              ListTile(
                                leading: const Icon(Icons.shield_outlined),
                                title: Text(
                                  user.isAdmin ? 'Admin' : 'Moderator',
                                ),
                                subtitle: const Text('Peran akunmu'),
                              ),
                            ListTile(
                              leading: const Icon(Icons.edit_outlined),
                              title: const Text('Ubah profil'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => _edit(context),
                            ),
                          ],
                        ),
                        if (user.isModerator) ...[
                          const _SectionLabel('Moderasi'),
                          _Card(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.flag_outlined),
                                title: const Text('Antrean laporan'),
                                subtitle: const Text(
                                  'Tinjau laporan konten dari pengguna',
                                ),
                                trailing: const _PendingBadge(),
                                onTap: () => Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => const ReportQueueScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const _SectionLabel('Tentang'),
                        _Card(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.description_outlined),
                              title: const Text('Syarat & Ketentuan'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => showLegalSheet(
                                context,
                                title: 'Syarat & Ketentuan',
                                sections: kTermsSections,
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.groups_outlined),
                              title: const Text('Aturan Komunitas'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => showLegalSheet(
                                context,
                                title: 'Aturan Komunitas',
                                sections: kCommunitySections,
                              ),
                            ),
                            const ListTile(
                              leading: Icon(Icons.info_outline_rounded),
                              title: Text('Versi aplikasi'),
                              subtitle: Text(kAppVersionLabel),
                            ),
                          ],
                        ),
                        const _SectionLabel('Sesi'),
                        _Card(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.logout_rounded),
                              title: const Text('Keluar'),
                              onTap: () => _signOut(context, ref),
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.delete_forever_outlined,
                                color: AppColors.error,
                              ),
                              title: const Text(
                                'Hapus akun',
                                style: TextStyle(color: AppColors.error),
                              ),
                              onTap: () => _deleteAccount(context, ref, user),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: 20,
      blur: 14,
      shadow: false,
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: children),
      ),
    );
  }
}

/// Lembar konfirmasi hapus akun: pengguna harus mengetik username-nya.
class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet({required this.username});

  final String username;

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final TextEditingController _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool get _matches => _typed.text.trim().toLowerCase() == widget.username;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hapus akun?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Profil, postingan, komentar, dan chat-mu akan dihapus dan tidak bisa '
              'dikembalikan. Kamu masih bisa mendaftar lagi dengan email yang sama, '
              'tetapi sebagai akun baru.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 16),
            GlassTextField(
              controller: _typed,
              label: 'Ketik @${widget.username} untuk konfirmasi',
              hintText: widget.username,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            GlassButton(
              label: 'Hapus akun permanen',
              variant: GlassButtonVariant.danger,
              onPressed: _matches
                  ? () => Navigator.of(context).pop(true)
                  : null,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Batal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Jumlah laporan menunggu di samping menu Antrean laporan.
class _PendingBadge extends ConsumerWidget {
  const _PendingBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(pendingReportCountProvider).asData?.value;
    if (n == null || n == 0) {
      return const Icon(Icons.chevron_right_rounded);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            '$n',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const Icon(Icons.chevron_right_rounded),
      ],
    );
  }
}
