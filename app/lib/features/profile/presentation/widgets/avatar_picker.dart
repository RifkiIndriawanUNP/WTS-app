import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/glass_sheet.dart';

/// Hasil memilih foto: [path] null berarti foto dihapus.
typedef AvatarPick = ({String? path});

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Pilih foto profil: kamera, galeri, atau hapus ([canRemove]). Mengembalikan
/// null bila dibatalkan atau foto ditolak (format/ukuran, pesan sudah tampil).
Future<AvatarPick?> pickAvatar(
  BuildContext context, {
  required bool canRemove,
}) async {
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
        if (canRemove)
          ListTile(
            leading: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
            ),
            title: const Text(
              'Hapus foto',
              style: TextStyle(color: AppColors.error),
            ),
            onTap: () => Navigator.of(ctx).pop('remove'),
          ),
        const SizedBox(height: 8),
      ],
    ),
  );
  if (choice == null || !context.mounted) {
    return null;
  }
  if (choice == 'remove') {
    return (path: null);
  }
  try {
    final picked = await ImagePicker().pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null || !context.mounted) {
      return null;
    }
    if (!Validators.isAllowedImagePath(picked.name)) {
      _snack(context, 'Format foto harus JPG, PNG, atau WebP');
      return null;
    }
    final size = await picked.length();
    if (!context.mounted) {
      return null;
    }
    if (size > AppConstants.maxAvatarBytes) {
      _snack(context, 'Ukuran foto maksimal 5 MB');
      return null;
    }
    return (path: picked.path);
  } catch (_) {
    if (context.mounted) {
      _snack(
        context,
        'Tidak bisa membuka kamera/galeri. Periksa izin aplikasi.',
      );
    }
    return null;
  }
}
