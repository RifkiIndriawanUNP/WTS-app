import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../auth_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../data/auth_repository.dart';
import '../../domain/legal_texts.dart';
import '../widgets/legal_sheet.dart';
import '../providers/auth_providers.dart';
import '../widgets/google_account_sheet.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  String? _error;
  bool _sending = false;
  bool _googleLoading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    final problem = Validators.email(_email.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).requestOtp(_email.text);
      if (!mounted) {
        return;
      }
      context.push(AuthRoutes.otp);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _continueWithGoogle() async {
    FocusScope.of(context).unfocus();
    final account = await showGoogleAccountSheet(context);
    if (account == null || !mounted) {
      return;
    }

    setState(() {
      _googleLoading = true;
      _error = null;
    });
    final result = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle(email: account.email);
    if (!mounted) {
      return;
    }
    setState(() => _googleLoading = false);

    switch (result.outcome) {
      case VerifyOutcome.existingUser:
        context.go(AuthRoutes.home);
      case VerifyOutcome.newUser:
        context.go(AuthRoutes.setupProfile);
      case VerifyOutcome.invalidDomain:
        setState(
          () => _error =
              'Akun Google harus memakai email kampus @${AppConstants.campusEmailDomain}',
        );
      case VerifyOutcome.banned:
      case VerifyOutcome.suspended:
        context.go(AuthRoutes.restricted);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busy = _sending || _googleLoading;

    return GlassScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/images/logo_wts.png', width: 72),
              const SizedBox(height: 28),
              GlassContainer(
                radius: 32,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, kawan kampus!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Masuk pakai akun kampusmu untuk jual, sewa, dan berbagi. Akunmu otomatis dibuat saat pertama kali masuk.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(child: _DomainBadge()),
                    const SizedBox(height: 16),
                    GlassTextField(
                      controller: _email,
                      hintText: 'nama@${AppConstants.campusEmailDomain}',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      errorText: _error,
                      enabled: !busy,
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      onSubmitted: (_) => _sendCode(),
                    ),
                    const SizedBox(height: 12),
                    GlassButton(
                      label: 'Kirim kode ke email',
                      variant: GlassButtonVariant.secondary,
                      loading: _sending,
                      onPressed: _googleLoading ? null : _sendCode,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            height: 1,
                            color: scheme.onSurface.withValues(alpha: 0.12),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'atau',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            height: 1,
                            color: scheme.onSurface.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    GlassButton(
                      label: 'Lanjut dengan Google',
                      leading: const _GoogleMark(),
                      loading: _googleLoading,
                      onPressed: _sending ? null : _continueWithGoogle,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Center(child: _LegalText()),
            ],
          ),
        ),
      ),
    );
  }
}

class _DomainBadge extends StatelessWidget {
  const _DomainBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassContainer(
      radius: 100,
      blur: 12,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 16,
            color: AppColors.brandBlue,
          ),
          const SizedBox(width: 8),
          Text(
            'Khusus akun @${AppConstants.campusEmailDomain}',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w800,
          fontSize: 15,
          height: 1,
        ),
      ),
    );
  }
}

class _LegalText extends StatefulWidget {
  const _LegalText();

  @override
  State<_LegalText> createState() => _LegalTextState();
}

class _LegalTextState extends State<_LegalText> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => showLegalSheet(
      context,
      title: 'Syarat & Ketentuan',
      sections: kTermsSections,
    );

  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => showLegalSheet(
      context,
      title: 'Aturan Komunitas',
      sections: kCommunitySections,
    );

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.5,
    );
    final link = base?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w700,
    );

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'Dengan masuk, kamu setuju dengan '),
          TextSpan(text: 'Syarat & Ketentuan', style: link, recognizer: _terms),
          const TextSpan(text: ' dan '),
          TextSpan(text: 'Aturan Komunitas', style: link, recognizer: _privacy),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
