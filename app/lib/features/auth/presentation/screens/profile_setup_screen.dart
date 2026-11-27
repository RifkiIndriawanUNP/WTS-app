import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../profile/domain/prodi.dart';
import '../../auth_routes.dart';
import '../../data/auth_repository.dart';
import '../../domain/legal_texts.dart';
import '../../domain/user_profile.dart';
import '../providers/auth_providers.dart';
import '../widgets/legal_sheet.dart';
import '../widgets/step_progress.dart';

enum _UsernameStatus { idle, invalid, checking, available, taken }

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final TextEditingController _bio = TextEditingController();
  final TextEditingController _username = TextEditingController();
  Timer? _debounce;

  _UsernameStatus _usernameStatus = _UsernameStatus.idle;
  String? _usernameError;
  Prodi? _prodi;
  bool _accepted = false;
  String? _avatarPath;
  String? _formError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authControllerProvider);
    final local = (auth.pendingEmail ?? '').split('@').first;

    _username.text = _usernameFromEmail(local);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (ref.read(authControllerProvider).pendingEmail == null) {
        context.go(AuthRoutes.login);
        return;
      }
      _onUsernameChanged(_username.text);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _bio.dispose();
    _username.dispose();
    super.dispose();
  }

  // ---- Prefill dari email ----------------------------------------------

  String _usernameFromEmail(String local) {
    var u = local.toLowerCase().replaceAll('.', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (u.length > AppConstants.usernameMax) {
      u = u.substring(0, AppConstants.usernameMax);
    }
    return u.length >= AppConstants.usernameMin ? u : '';
  }

  // ---- Username --------------------------------------------------------

  void _onUsernameChanged(String raw) {
    _debounce?.cancel();
    final value = Validators.normalizeUsername(raw);
    final problem = Validators.username(value);

    if (problem != null) {
      setState(() {
        _usernameStatus = value.isEmpty ? _UsernameStatus.idle : _UsernameStatus.invalid;
        _usernameError = value.isEmpty ? null : problem;
      });
      return;
    }

    setState(() {
      _usernameStatus = _UsernameStatus.checking;
      _usernameError = null;
    });
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final ok = await ref.read(authControllerProvider.notifier).isUsernameAvailable(value);
      if (!mounted || value != Validators.normalizeUsername(_username.text)) {
        return;
      }
      setState(() {
        _usernameStatus = ok ? _UsernameStatus.available : _UsernameStatus.taken;
        _usernameError = ok ? null : 'Username sudah dipakai';
      });
    });
  }

  Widget? _usernameSuffix(ThemeData theme) {
    switch (_usernameStatus) {
      case _UsernameStatus.checking:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _UsernameStatus.available:
        return Text(
          'Tersedia',
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w700,
          ),
        );
      case _UsernameStatus.idle:
      case _UsernameStatus.invalid:
      case _UsernameStatus.taken:
        return null;
    }
  }

  // ---- Foto profil -----------------------------------------------------

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickAvatar() async {
    FocusScope.of(context).unfocus();
    final choice = await showGlassSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Ambil foto'),
            onTap: () => Navigator.of(ctx).pop('camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Pilih dari galeri'),
            onTap: () => Navigator.of(ctx).pop('gallery'),
          ),
          if (_avatarPath != null)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text('Hapus foto', style: TextStyle(color: AppColors.error)),
              onTap: () => Navigator.of(ctx).pop('remove'),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (choice == null || !mounted) {
      return;
    }

    if (choice == 'remove') {
      setState(() => _avatarPath = null);
      return;
    }

    try {
      final picked = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null || !mounted) {
        return;
      }

      if (!Validators.isAllowedImagePath(picked.name)) {
        _snack('Format foto harus JPG, PNG, atau WebP');
        return;
      }
      final size = await picked.length(); // aman di web & Android
      if (!mounted) {
        return;
      }
      if (size > AppConstants.maxAvatarBytes) {
        _snack('Ukuran foto maksimal 5 MB');
        return;
      }
      setState(() => _avatarPath = picked.path);
    } catch (_) {
      if (mounted) _snack('Tidak bisa membuka kamera/galeri. Periksa izin aplikasi.');
    }
  }

  // ---- Program studi ---------------------------------------------------------

  Future<void> _pickProdi() async {
    FocusScope.of(context).unfocus();
    final result = await showOptionPicker(
      context,
      title: 'Pilih program studi',
      options: [for (final p in kFakeProdi) p.name],
      selected: _prodi?.name,
      allowClear: true,
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      if (result.isEmpty) {
        _prodi = null;
      } else {
        _prodi = kFakeProdi.firstWhere((p) => p.name == result);
      }
    });
  }

  // ---- Kirim -----------------------------------------------------------

  bool get _canSubmit =>
      !_submitting &&
      _accepted &&
      Validators.bio(_bio.text) == null &&
      _usernameStatus == _UsernameStatus.available;

  void _back() {
    ref.read(authControllerProvider.notifier).cancelPending();
    context.go(AuthRoutes.login);
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _formError = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).completeProfile(
            username: Validators.normalizeUsername(_username.text),
            acceptedTerms: _accepted,
            prodiId: _prodi?.id,
            bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
            avatarPath: _avatarPath,
          );
      if (!mounted) {
        return;
      }
      context.go(AuthRoutes.home);
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _formError = e.message;
        if (e.code == 'username_taken') {
          _usernameStatus = _UsernameStatus.taken;
          _usernameError = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final initials = UserProfile.initialsOf(Validators.normalizeUsername(_username.text));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: GlassScaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StepProgressHeader(current: 2, total: 2, onBack: _back),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        'Kenalan dulu, yuk',
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ini hanya sekali, pertama kali kamu masuk. Pengguna lain mengenalmu lewat @username; tidak ada nama asli yang ditampilkan.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Stack(
                          children: [
                            UserAvatar(initials: initials, imagePath: _avatarPath, size: 112),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Semantics(
                                button: true,
                                label: 'Ubah foto profil',
                                child: GestureDetector(
                                  onTap: _pickAvatar,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: scheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.photo_camera_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      GlassTextField(
                        controller: _username,
                        label: 'Username',
                        hintText: 'username',
                        prefixText: '@',
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                          LowerCaseTextFormatter(),
                          LengthLimitingTextInputFormatter(AppConstants.usernameMax),
                        ],
                        suffix: _usernameSuffix(theme),
                        errorText: _usernameError,
                        onChanged: _onUsernameChanged,
                      ),
                      const SizedBox(height: 16),
                      GlassSelectField(
                        label: 'Program studi (opsional)',
                        hintText: 'Pilih program studi',
                        prefixIcon: Icons.school_outlined,
                        value: _prodi?.name,
                        onTap: _pickProdi,
                      ),
                      const SizedBox(height: 16),
                      GlassTextArea(
                        controller: _bio,
                        label: 'Bio (opsional)',
                        hintText: 'Ceritakan sedikit tentangmu',
                        maxLength: AppConstants.bioMax,
                        minLines: 3,
                        maxLines: 5,
                        errorText: Validators.bio(_bio.text),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      _LegalAgreement(
                        accepted: _accepted,
                        onChanged: (v) => setState(() => _accepted = v),
                      ),
                      const SizedBox(height: 24),
                      if (_formError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _formError!,
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
                          ),
                        ),
                      Center(
                        child: Text(
                          'Username bisa diganti 1x per 30 hari di Profil.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 14),
                      GlassButton(
                        label: 'Selesai',
                        loading: _submitting,
                        onPressed: _canSubmit ? _submit : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Baris persetujuan: kotak centang + kalimat kecil dengan tautan yang rapi
/// (ukuran sama dengan teks biasa, hanya berwarna dan bergaris bawah).
class _LegalAgreement extends StatefulWidget {
  const _LegalAgreement({required this.accepted, required this.onChanged});

  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  State<_LegalAgreement> createState() => _LegalAgreementState();
}

class _LegalAgreementState extends State<_LegalAgreement> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => showLegalSheet(
          context,
          title: 'Syarat & Ketentuan',
          sections: kTermsSections,
        );
  late final TapGestureRecognizer _community = TapGestureRecognizer()
    ..onTap = () => showLegalSheet(
          context,
          title: 'Aturan Komunitas',
          sections: kCommunitySections,
        );

  @override
  void dispose() {
    _terms.dispose();
    _community.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.45,
    );
    final link = base?.copyWith(
      color: AppColors.brandBlue,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.brandBlue,
    );

    return Row(
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            value: widget.accepted,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (v) => widget.onChanged(v ?? false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: base,
              children: [
                const TextSpan(text: 'Saya setuju dengan '),
                TextSpan(text: 'Syarat & Ketentuan', style: link, recognizer: _terms),
                const TextSpan(text: ' dan '),
                TextSpan(text: 'Aturan Komunitas', style: link, recognizer: _community),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
