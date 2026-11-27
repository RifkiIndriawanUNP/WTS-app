import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/post_draft_store.dart';
import '../../data/post_repository.dart';
import '../../domain/post.dart';
import '../providers/feed_providers.dart';
import '../widgets/post_image_gallery.dart';
import '../widgets/post_tag_chip.dart';

/// Layar "Buat Postingan" (dan "Ubah Postingan" bila [editing] diisi).
/// Menutup dengan [Post] hasil (dibuat/diubah), atau null bila dibatalkan.
///
/// Mode ubah: hanya caption yang bisa diganti, dalam 24 jam pertama.
/// Tag, gambar, anonim, dan durasi dikunci (aturan backend).
class PostFormScreen extends ConsumerStatefulWidget {
  const PostFormScreen({super.key, this.editing});

  final Post? editing;

  @override
  ConsumerState<PostFormScreen> createState() => _PostFormScreenState();
}

class _PostFormScreenState extends ConsumerState<PostFormScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final TextEditingController _link = TextEditingController();
  final TextEditingController _minutes = TextEditingController();

  final List<int> _tagIds = [];
  final List<PostImage> _images = [];
  bool _anonymous = false;
  int _days = PostRules.defaultLifetimeDays;
  DateTime? _deadline;

  bool _submitting = false;
  bool _restoredDraft = false;
  String? _error;
  Timer? _draftTimer;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final post = widget.editing;
    if (post != null) {
      final parts = post.parts;
      _title.text = parts.title ?? '';
      _body.text = parts.body;
      _anonymous = post.isAnonymous;
      _tagIds.addAll(post.tags.map((t) => t.id));
      _images.addAll(post.images);
    } else {
      _loadDraft();
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _title.dispose();
    _body.dispose();
    _link.dispose();
    _minutes.dispose();
    super.dispose();
  }

  // ---- Draf --------------------------------------------------------------

  Future<void> _loadDraft() async {
    final draft = await PostDraftStore.load();
    if (draft == null || !mounted) {
      return;
    }
    setState(() {
      _title.text = draft.title;
      _body.text = draft.body;
      _link.text = draft.link;
      _tagIds
        ..clear()
        ..addAll(draft.tagIds);
      _anonymous = draft.anonymous;
      _days = PostRules.lifetimeDays.contains(draft.days) ? draft.days : _days;
      _restoredDraft = true;
    });
  }

  void _changed() {
    setState(() => _error = null);
    if (_isEdit) {
      return;
    }
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 600), _saveDraft);
  }

  Future<void> _saveDraft() {
    return PostDraftStore.save(
      PostFormDraft(
        title: _title.text,
        body: _body.text,
        tagIds: List.of(_tagIds),
        anonymous: _anonymous,
        days: _days,
        link: _link.text,
      ),
    );
  }

  Future<void> _discardDraft() async {
    _draftTimer?.cancel();
    await PostDraftStore.clear();
    if (!mounted) {
      return;
    }
    setState(() {
      _title.clear();
      _body.clear();
      _link.clear();
      _tagIds.clear();
      _anonymous = false;
      _days = PostRules.defaultLifetimeDays;
      _restoredDraft = false;
    });
  }

  // ---- Isian -------------------------------------------------------------

  String get _caption => PostRules.compose(_title.text, _body.text);

  bool _isQuestionnaire(List<PostTag> tags) => tags.any(
    (t) => _tagIds.contains(t.id) && t.slug == PostRules.questionnaireSlug,
  );

  String? get _linkError {
    final v = _link.text.trim();
    if (v.isEmpty || RegExp(r'^https?://', caseSensitive: false).hasMatch(v)) {
      return null;
    }
    return 'Tautan harus diawali http:// atau https://';
  }

  String? get _captionError {
    final hasText =
        _title.text.trim().isNotEmpty || _body.text.trim().isNotEmpty;
    if (!hasText) {
      return null; // belum mengetik: jangan tampilkan galat dulu
    }
    return PostRules.validateCaption(_caption);
  }

  bool get _canSubmit {
    if (_submitting || PostRules.validateCaption(_caption) != null) {
      return false;
    }
    if (_isEdit) {
      return _caption != widget.editing!.caption.trim();
    }
    return _tagIds.isNotEmpty &&
        _tagIds.length <= PostRules.maxTags &&
        _linkError == null;
  }

  void _toggleTag(PostTag tag) {
    setState(() {
      if (_tagIds.contains(tag.id)) {
        _tagIds.remove(tag.id);
      } else if (_tagIds.length >= PostRules.maxTags) {
        _snack('Maksimal ${PostRules.maxTags} tag');
        return;
      } else {
        _tagIds.add(tag.id);
      }
    });
    _changed();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- Gambar ------------------------------------------------------------

  Future<void> _addImages() async {
    FocusScope.of(context).unfocus();
    final remaining = PostRules.maxImages - _images.length;
    if (remaining <= 0) {
      _snack('Maksimal ${PostRules.maxImages} gambar');
      return;
    }
    final source = await showGlassSheet<ImageSource>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil foto'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) {
      return;
    }

    try {
      final picker = ImagePicker();
      List<XFile> picked;
      if (source == ImageSource.camera || remaining == 1) {
        final one = await picker.pickImage(
          source: source,
          maxWidth: 1080,
          maxHeight: 1080,
          imageQuality: 70,
        );
        picked = one == null ? [] : [one];
      } else {
        picked = await picker.pickMultiImage(
          limit: remaining,
          maxWidth: 1080,
          maxHeight: 1080,
          imageQuality: 70,
        );
      }
      if (!mounted || picked.isEmpty) {
        return;
      }

      var rejected = 0;
      final added = <PostImage>[];
      for (final x in picked.take(remaining)) {
        final name = x.name.isNotEmpty ? x.name : x.path;
        if (Validators.isAllowedImagePath(name)) {
          added.add(PostImage(path: x.path));
        } else {
          rejected++;
        }
      }
      setState(() => _images.addAll(added));
      if (rejected > 0) {
        _snack('Hanya gambar JPG, PNG, atau WebP (tanpa GIF/video)');
      }
    } catch (_) {
      if (mounted) {
        _snack('Tidak bisa membuka galeri/kamera. Periksa izin aplikasi.');
      }
    }
  }

  // ---- Kirim -------------------------------------------------------------

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _submit(List<PostTag> tags) async {
    if (!_canSubmit) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    final controller = ref.read(feedControllerProvider.notifier);
    try {
      final Post result;
      if (_isEdit) {
        result = await controller.updateCaption(widget.editing!, _caption);
      } else {
        final link = _link.text.trim();
        final questionnaire = _isQuestionnaire(tags) && link.isNotEmpty
            ? QuestionnaireInfo(
                link: link,
                deadline: _deadline,
                durationMin: int.tryParse(_minutes.text.trim()),
              )
            : null;
        result = await controller.createPost(
          PostDraft(
            caption: _caption.trim(),
            tagIds: List.of(_tagIds),
            images: List.of(_images),
            isAnonymous: _anonymous,
            lifetimeDays: _days,
            questionnaire: questionnaire,
          ),
        );
        _draftTimer?.cancel();
        await PostDraftStore.clear();
      }
      if (!mounted) {
        return;
      }
      // Gambar sudah terkirim: kosongkan agar PopScope tidak bertanya lagi.
      setState(_images.clear);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop(result);
        }
      });
    } on PostException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _submitting = false;
        });
      }
    }
  }

  Future<void> _confirmLeave(bool didPop) async {
    if (didPop) {
      return;
    }
    final ok = await showGlassConfirm(
      context,
      title: 'Keluar tanpa memposting?',
      message: 'Gambar yang sudah kamu pilih tidak ikut tersimpan di draf.',
      confirmLabel: 'Keluar',
      destructive: true,
    );
    if (ok == true && mounted) {
      setState(_images.clear);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).maybePop();
        }
      });
    }
  }

  // ---- Tampilan ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = ref.watch(authControllerProvider.select((s) => s.user));
    final tagsAsync = ref.watch(timelineTagsProvider);
    final tags = tagsAsync.asData?.value ?? const <PostTag>[];

    return PopScope(
      canPop: _images.isEmpty || _isEdit,
      onPopInvokedWithResult: (didPop, _) => _confirmLeave(didPop),
      child: GlassScaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Kembali',
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Text(
                        _isEdit ? 'Ubah Postingan' : 'Buat Postingan',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: _canSubmit ? () => _submit(tags) : null,
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                              ),
                            )
                          : Text(_isEdit ? 'Simpan' : 'Posting'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    // Penulis
                    Row(
                      children: [
                        UserAvatar(
                          initials: _anonymous ? '?' : (user?.initials ?? '?'),
                          imagePath: _anonymous ? null : user?.avatarPath,
                          size: 44,
                          glass: false,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _anonymous
                                    ? 'Anonim'
                                    : '@${user?.username ?? '-'}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                [
                                  if (!_anonymous && user?.prodiName != null)
                                    user!.prodiName!,
                                  'Mahasiswa terverifikasi',
                                ].join(' · '),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_restoredDraft)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassContainer(
                          radius: 16,
                          blur: 10,
                          shadow: false,
                          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                          child: Row(
                            children: [
                              const Icon(Icons.edit_note_rounded, size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text('Draf terakhirmu dipulihkan'),
                              ),
                              TextButton(
                                onPressed: _discardDraft,
                                child: const Text('Buang'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_isEdit)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Hanya isi postingan yang bisa diubah (dalam 24 jam pertama). '
                          'Tag, gambar, dan pilihan anonim tetap.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ),

                    // Anonim
                    GlassContainer(
                      radius: 20,
                      blur: 12,
                      shadow: false,
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.visibility_off_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Posting anonim',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Namamu disembunyikan dari feed',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _anonymous,
                            onChanged: _isEdit
                                ? null
                                : (v) {
                                    setState(() => _anonymous = v);
                                    _changed();
                                  },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Kategori
                    Text.rich(
                      TextSpan(
                        text: 'Kategori',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        children: const [
                          TextSpan(
                            text: ' *',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pilih 1–${PostRules.maxTags} kategori.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (tagsAsync.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      )
                    else if (tagsAsync.hasError)
                      TextButton(
                        onPressed: () => ref.invalidate(timelineTagsProvider),
                        child: const Text('Gagal memuat kategori. Coba lagi'),
                      )
                    else if (_isEdit)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final t in widget.editing!.tags)
                            PostTagChip(label: t.name),
                        ],
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in tags)
                            GlassChip(
                              label: t.name,
                              selected: _tagIds.contains(t.id),
                              onTap: () => _toggleTag(t),
                            ),
                        ],
                      ),
                    const SizedBox(height: 18),

                    // Judul + isi
                    GlassTextField(
                      controller: _title,
                      hintText: 'Judul (opsional)',
                      maxLength: PostRules.titleMax,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _changed(),
                    ),
                    const SizedBox(height: 12),
                    GlassTextArea(
                      controller: _body,
                      hintText: 'Tulis isi postingan. Tautan boleh disertakan.',
                      maxLength: PostRules.captionMax,
                      minLines: 6,
                      maxLines: 14,
                      errorText: _captionError,
                      onChanged: (_) => _changed(),
                    ),

                    // Kuesioner
                    if (!_isEdit && _isQuestionnaire(tags)) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Detail kuesioner (opsional)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GlassTextField(
                        controller: _link,
                        hintText: 'https://forms.gle/...',
                        prefixIcon: Icons.link_rounded,
                        keyboardType: TextInputType.url,
                        errorText: _linkError,
                        onChanged: (_) => _changed(),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDeadline,
                              icon: const Icon(Icons.event_outlined, size: 18),
                              label: Text(
                                _deadline == null
                                    ? 'Batas waktu'
                                    : Fmt.date(_deadline!),
                              ),
                            ),
                          ),
                          if (_deadline != null)
                            IconButton(
                              tooltip: 'Hapus batas waktu',
                              onPressed: () => setState(() => _deadline = null),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 140,
                            child: GlassTextField(
                              controller: _minutes,
                              hintText: 'Menit',
                              keyboardType: TextInputType.number,
                              maxLength: 3,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Gambar
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text(
                          'Gambar',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_images.length}/${PostRules.maxImages}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 88,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (var i = 0; i < _images.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: _Thumb(
                                image: _images[i],
                                onRemove: _isEdit
                                    ? null
                                    : () => setState(() => _images.removeAt(i)),
                              ),
                            ),
                          if (!_isEdit && _images.length < PostRules.maxImages)
                            InkWell(
                              onTap: _addImages,
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppColors.brandBlue.withValues(
                                      alpha: 0.6,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'JPG, PNG, atau WebP. Tanpa GIF atau video.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),

                    // Durasi
                    if (!_isEdit) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Hilang otomatis setelah',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final d in PostRules.lifetimeDays)
                            GlassChip(
                              label: '$d hari',
                              selected: _days == d,
                              onTap: () {
                                setState(() => _days = d);
                                _changed();
                              },
                            ),
                        ],
                      ),
                    ],

                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.error,
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

class _Thumb extends StatelessWidget {
  const _Thumb({required this.image, required this.onRemove});

  final PostImage image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: PostImageView(image: image),
          ),
          if (onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
