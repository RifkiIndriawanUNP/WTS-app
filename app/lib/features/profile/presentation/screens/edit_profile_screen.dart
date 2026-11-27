import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/user_profile.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/prodi.dart';
import '../widgets/avatar_picker.dart';

enum _NameStatus { unchanged, invalid, checking, available, taken }

/// Ubah profil: foto, username (1x per 30 hari), program studi, bio.
/// Menutup dengan `true` bila tersimpan.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final UserProfile _user = ref.read(authControllerProvider).user!;
  late final TextEditingController _username = TextEditingController(
    text: _user.username,
  );
  late final TextEditingController _bio = TextEditingController(
    text: _user.bio ?? '',
  );
  late Prodi? _prodi = findFakeProdi(_user.prodiId);
  late String? _avatarPath = _user.avatarPath;

  Timer? _debounce;
  _NameStatus _nameStatus = _NameStatus.unchanged;
  String? _nameError;
  String? _formError;
  bool _saving = false;

  DateTime? get _unlockAt => _user.usernameUnlockAt(DateTime.now());
  bool get _locked => _unlockAt != null;

  @override
  void dispose() {
    _debounce?.cancel();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _onUsername(String raw) {
    _debounce?.cancel();
    final value = Validators.normalizeUsername(raw);
    if (value == _user.username) {
      setState(() {
        _nameStatus = _NameStatus.unchanged;
        _nameError = null;
      });
      return;
    }
    final problem = Validators.username(value);
    if (problem != null) {
      setState(() {
        _nameStatus = _NameStatus.invalid;
        _nameError = problem;
      });
      return;
    }
    setState(() {
      _nameStatus = _NameStatus.checking;
      _nameError = null;
    });
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final ok = await ref
          .read(authControllerProvider.notifier)
          .isUsernameAvailable(value);
      if (!mounted || value != Validators.normalizeUsername(_username.text)) {
        return;
      }
      setState(() {
        _nameStatus = ok ? _NameStatus.available : _NameStatus.taken;
        _nameError = ok ? null : 'Username sudah dipakai';
      });
    });
  }

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

  Future<void> _pickPhoto() async {
    final pick = await pickAvatar(context, canRemove: _avatarPath != null);
    if (pick != null && mounted) {
      setState(() => _avatarPath = pick.path);
    }
  }

  bool get _changed =>
      Validators.normalizeUsername(_username.text) != _user.username ||
      _prodi?.id != _user.prodiId ||
      _bio.text.trim() != (_user.bio ?? '') ||
      _avatarPath != _user.avatarPath;

  bool get _canSave {
    if (_saving || !_changed || Validators.bio(_bio.text) != null) {
      return false;
    }
    return _nameStatus == _NameStatus.unchanged ||
        _nameStatus == _NameStatus.available;
  }

  Future<void> _save() async {
    if (!_canSave) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      final bio = _bio.text.trim();
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            username: Validators.normalizeUsername(_username.text),
            prodiId: _prodi?.id,
            bio: bio.isEmpty ? null : bio,
            avatarPath: _avatarPath,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _formError = e.message;
        if (e.code == 'username_taken') {
          _nameStatus = _NameStatus.taken;
          _nameError = e.message;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget? _nameSuffix(ThemeData theme) {
    switch (_nameStatus) {
      case _NameStatus.checking:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _NameStatus.available:
        return Text(
          'Tersedia',
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w700,
          ),
        );
      case _NameStatus.unchanged:
      case _NameStatus.invalid:
      case _NameStatus.taken:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unlock = _unlockAt;
    final initials = UserProfile.initialsOf(
      Validators.normalizeUsername(_username.text),
    );

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
                    'Ubah Profil',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          UserAvatar(
                            initials: initials,
                            imagePath: _avatarPath,
                            size: 112,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Semantics(
                              button: true,
                              label: 'Ubah foto profil',
                              child: GestureDetector(
                                onTap: _pickPhoto,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
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
                      enabled: !_locked && !_saving,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9_]'),
                        ),
                        LowerCaseTextFormatter(),
                        LengthLimitingTextInputFormatter(
                          AppConstants.usernameMax,
                        ),
                      ],
                      suffix: _nameSuffix(theme),
                      errorText: _nameError,
                      onChanged: _onUsername,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                      child: Text(
                        unlock != null
                            ? 'Username baru bisa diganti lagi pada ${Fmt.date(unlock)}.'
                            : 'Username hanya bisa diganti 1x per ${AppConstants.usernameChangeCooldownDays} hari.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
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
                    const SizedBox(height: 24),
                    if (_formError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _formError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    GlassButton(
                      label: 'Simpan',
                      loading: _saving,
                      onPressed: _canSave ? _save : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
