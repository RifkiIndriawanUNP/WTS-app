import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../auth_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../data/auth_repository.dart';
import '../providers/auth_providers.dart';
import '../widgets/otp_input.dart';
import '../widgets/step_progress.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final TextEditingController _code = TextEditingController();
  Timer? _timer;
  int _seconds = AppConstants.otpResendSeconds;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // Tanpa email yang sedang diverifikasi, layar ini tidak bermakna.
      if (ref.read(authControllerProvider).pendingEmail == null) {
        context.go(AuthRoutes.login);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _seconds = AppConstants.otpResendSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_seconds <= 1) {
        t.cancel();
        setState(() => _seconds = 0);
      } else {
        setState(() => _seconds--);
      }
    });
  }

  String get _timeLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _changeEmail() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AuthRoutes.login);
    }
  }

  Future<void> _resend() async {
    if (_seconds > 0 || _resending) {
      return;
    }
    setState(() => _resending = true);
    try {
      await ref.read(authControllerProvider.notifier).resendOtp();
      if (!mounted) {
        return;
      }
      setState(() {
        _error = null;
        _code.clear();
        _startTimer();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode baru sudah dikirim ke emailmu')),
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _verify([String? value]) async {
    final code = value ?? _code.text;
    if (code.length != AppConstants.otpLength || _verifying) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _verifying = true;
      _error = null;
    });
    final result = await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(code);
    if (!mounted) {
      return;
    }
    setState(() => _verifying = false);

    switch (result.outcome) {
      case VerifyOutcome.existingUser:
        context.go(AuthRoutes.home);
      case VerifyOutcome.newUser:
        context.go(AuthRoutes.setupProfile);
      case VerifyOutcome.invalidCode:
        setState(() {
          _error = 'Kode salah. Sisa percobaan: ${result.attemptsLeft}';
          _code.clear();
        });
      case VerifyOutcome.expired:
        setState(() {
          _error = 'Kode sudah kedaluwarsa. Kirim ulang kode baru.';
          _seconds = 0;
          _code.clear();
        });
      case VerifyOutcome.tooManyAttempts:
        setState(() {
          _error = 'Terlalu banyak percobaan salah. Kirim ulang kode baru.';
          _seconds = 0;
          _code.clear();
        });
      case VerifyOutcome.banned:
      case VerifyOutcome.suspended:
        context.go(AuthRoutes.restricted);
      case VerifyOutcome.invalidDomain:
        context.go(AuthRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final email =
        ref.watch(authControllerProvider.select((s) => s.pendingEmail)) ?? '';

    return GlassScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StepProgressHeader(current: 1, total: 2, onBack: _changeEmail),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Text(
                      'Cek Email Kampusmu',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text.rich(
                      TextSpan(
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(
                            text:
                                'Kami telah mengirimkan kode verifikasi ${AppConstants.otpLength} digit ke ',
                          ),
                          TextSpan(
                            text: email,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Pastikan alamat email sudah benar. ',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        GestureDetector(
                          onTap: _changeEmail,
                          child: Text(
                            'Ganti email',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    OtpInput(
                      controller: _code,
                      hasError: _error != null,
                      enabled: !_verifying,
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      onCompleted: _verify,
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
                    const SizedBox(height: 20),
                    Center(
                      child: _seconds > 0
                          ? Text.rich(
                              TextSpan(
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Kirim ulang kode dalam ',
                                  ),
                                  TextSpan(
                                    text: _timeLabel,
                                    style: TextStyle(
                                      color: scheme.onSurface,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : TextButton(
                              onPressed: _resending ? null : _resend,
                              child: Text(
                                _resending ? 'Mengirim...' : 'Kirim ulang kode',
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    GlassContainer(
                      radius: 18,
                      blur: 14,
                      shadow: false,
                      tint: AppColors.secondary,
                      tintOpacity: 0.16,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 18,
                            color: AppColors.brandBlue,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Belum masuk? Cek folder Spam. Kode berlaku ${AppConstants.otpValidMinutes} menit dan hanya bisa dipakai sekali.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurface,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Mode simulasi: kode OTP = ${AppConstants.simulatedOtp}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ListenableBuilder(
                      listenable: _code,
                      builder: (context, _) => GlassButton(
                        label: 'Verifikasi',
                        loading: _verifying,
                        onPressed: _code.text.length == AppConstants.otpLength
                            ? _verify
                            : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        'Hanya email @${AppConstants.campusEmailDomain} yang bisa menerima kode',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
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
