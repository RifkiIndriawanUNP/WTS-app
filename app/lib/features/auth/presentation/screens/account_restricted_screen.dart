import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../moderation/data/report_repository.dart';
import '../../../moderation/domain/moderation_action.dart';
import '../../../moderation/presentation/providers/report_providers.dart';
import '../../auth_routes.dart';
import '../providers/auth_providers.dart';

/// Layar untuk akun yang ditangguhkan (sementara) atau diblokir (permanen).
class AccountRestrictedScreen extends ConsumerStatefulWidget {
  const AccountRestrictedScreen({super.key});

  @override
  ConsumerState<AccountRestrictedScreen> createState() =>
      _AccountRestrictedScreenState();
}

class _AccountRestrictedScreenState
    extends ConsumerState<AccountRestrictedScreen> {
  bool _appealSent = false;

  Future<void> _appeal() async {
    final text = await showGlassSheet<String>(
      context: context,
      builder: (ctx) => const _AppealForm(),
    );
    if (text == null || !mounted) {
      return;
    }
    String msg;
    try {
      await ref.read(reportRepositoryProvider).submitAppeal(message: text);
      msg = 'Banding terkirim. Admin akan meninjaunya.';
      setState(() => _appealSent = true);
    } on ReportException catch (e) {
      msg = e.message;
      if (e.code == 'already_appealed') {
        setState(() => _appealSent = true);
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final restriction = ref.watch(
      authControllerProvider.select((s) => s.restriction),
    );
    final banned = restriction?.banned ?? true;
    final until = restriction?.until;

    final title = banned ? 'Akunmu diblokir' : 'Akunmu ditangguhkan';
    final message = banned
        ? 'Akun ini diblokir permanen karena melanggar aturan komunitas WTS.'
        : 'Akun ini ditangguhkan sementara karena melanggar aturan komunitas'
              '${until == null ? '' : ' sampai ${Fmt.date(until)}'}.'
              ' Kamu bisa masuk lagi setelah masa penangguhan selesai.';

    return GlassScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GlassContainer(
                radius: 32,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      banned
                          ? Icons.block_rounded
                          : Icons.pause_circle_outline_rounded,
                      size: 56,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Merasa ini keliru? Ajukan banding satu kali untuk ditinjau admin.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 22),
                    GlassButton(
                      label: _appealSent
                          ? 'Banding sudah diajukan'
                          : 'Ajukan banding',
                      variant: GlassButtonVariant.secondary,
                      onPressed: _appealSent ? null : _appeal,
                    ),
                    const SizedBox(height: 10),
                    GlassButton(
                      label: 'Kembali ke halaman masuk',
                      onPressed: () {
                        ref
                            .read(authControllerProvider.notifier)
                            .cancelPending();
                        context.go(AuthRoutes.login);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppealForm extends StatefulWidget {
  const _AppealForm();

  @override
  State<_AppealForm> createState() => _AppealFormState();
}

class _AppealFormState extends State<_AppealForm> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        Text(
          'Ajukan banding',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Jelaskan kenapa keputusan ini keliru. Banding hanya bisa diajukan satu kali.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        GlassTextArea(
          controller: _text,
          hintText: 'Pesan banding',
          maxLength: ModerationRules.appealMax,
          minLines: 4,
          maxLines: 8,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        GlassButton(
          label: 'Kirim banding',
          onPressed: _text.text.trim().length >= ModerationRules.appealMin
              ? () => Navigator.of(context).pop(_text.text.trim())
              : null,
        ),
      ],
    );
  }
}
