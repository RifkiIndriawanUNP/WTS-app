import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wts/core/utils/guard.dart';
import 'package:wts/features/chat/domain/chat_models.dart';
import 'package:wts/features/chat/presentation/message_widgets.dart';
import 'package:wts/shared/widgets/app_icons.dart';
import 'package:wts/shared/widgets/dialogs.dart';

/// Aksi cepat bersama untuk DM dan chat market: foto, lokasi, kontak, tautan.
/// [leading] = aksi tambahan di depan (mis. "Tawar" di chat market).
List<ComposerAction> buildShareActions(
  BuildContext context,
  SendMessageFn send, {
  List<ComposerAction> leading = const [],
}) {
  return [
    ...leading,
    ComposerAction(
      label: 'Foto',
      icon: WtsIcons.image,
      onTap: () => _sharePhoto(context, send),
    ),
    ComposerAction(
      label: 'Lokasi',
      icon: WtsIcons.pin,
      onTap: () => _shareLocation(context, send),
    ),
    ComposerAction(
      label: 'Kontak WA',
      icon: WtsIcons.phone,
      onTap: () => _shareContact(context, send),
    ),
    ComposerAction(
      label: 'Tautan',
      icon: WtsIcons.link,
      onTap: () => _shareLink(context, send),
    ),
  ];
}

/// Ambil foto dari galeri (atau kamera bila [camera]) lalu kirim.
Future<void> sharePhoto(
  BuildContext context,
  SendMessageFn send, {
  bool camera = false,
}) =>
    _sharePhoto(context, send, camera: camera);

Future<void> _sharePhoto(
  BuildContext context,
  SendMessageFn send, {
  bool camera = false,
}) async {
  final picker = ImagePicker();

  final XFile? photo = await picker.pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    imageQuality: 85,
  );

  if (photo == null || !context.mounted) return;

  await guarded(
    context,
    () => send(MessageType.image, meta: {'imagePath': photo.path}),
  );
}

Future<void> _shareLocation(BuildContext context, SendMessageFn send) async {
  final ok = await confirmDialog(
    context,
    title: 'Bagikan lokasi?',
    message:
        'Lokasi dikirim sekali saja (tanpa pelacakan). '
        'Saat ini memakai koordinat contoh sampai geolocator dipasang.',
    confirmLabel: 'Bagikan',
  );
  if (!ok || !context.mounted) return;
  await guarded(
    context,
    () => send(MessageType.location, meta: {'lat': -6.9040, 'lng': 106.9260}),
  );
}

Future<void> _shareContact(BuildContext context, SendMessageFn send) async {
  final phone = await textInputDialog(
    context,
    title: 'Bagikan nomor WhatsApp-mu?',
    message: 'Nomor akan terlihat oleh lawan bicara di chat ini.',
    hint: '0812xxxxxxxx',
    keyboardType: TextInputType.phone,
    confirmLabel: 'Bagikan',
    validator: (v) {
      final cleaned = v.replaceAll(RegExp(r'[\s-]'), '');
      return RegExp(r'^\+?[0-9]{8,15}$').hasMatch(cleaned)
          ? null
          : 'Nomor tidak valid (8-15 digit)';
    },
  );
  if (phone == null || !context.mounted) return;
  await guarded(
    context,
    () => send(
      MessageType.contact,
      meta: {'phone': phone.replaceAll(RegExp(r'[\s-]'), '')},
    ),
  );
}

Future<void> _shareLink(BuildContext context, SendMessageFn send) async {
  final url = await textInputDialog(
    context,
    title: 'Kirim tautan',
    hint: 'https://...',
    keyboardType: TextInputType.url,
    validator: (v) {
      final uri = Uri.tryParse(v);
      final ok =
          uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
      return ok ? null : 'Gunakan tautan http:// atau https://';
    },
  );
  if (url == null || !context.mounted) return;
  await guarded(context, () => send(MessageType.link, body: url));
}