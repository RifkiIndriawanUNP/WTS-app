import 'package:flutter/material.dart';

import '../../../../shared/widgets/glass_sheet.dart';

class GoogleAccount {
  const GoogleAccount(this.name, this.email);

  final String name;
  final String email;
}

/// Akun contoh untuk menguji alur tanpa Google Sign-In sungguhan.
const List<GoogleAccount> _testAccounts = [
  GoogleAccount('Fajar Kurniawan', 'fajar.kurniawan@nusaputra.ac.id'),
  GoogleAccount('Rina (Gmail pribadi)', 'rina.pribadi@gmail.com'),
  GoogleAccount('Akun Admin (uji)', 'admin@nusaputra.ac.id'),
  GoogleAccount('Akun Diblokir (uji)', 'banned@nusaputra.ac.id'),
  GoogleAccount('Akun Ditangguhkan (uji)', 'suspended@nusaputra.ac.id'),
];

/// SIMULASI pemilih akun Google. Ganti dengan google_sign_in / Supabase OAuth
/// saat backend siap; hasilnya tetap berupa nama + email.
Future<GoogleAccount?> showGoogleAccountSheet(BuildContext context) {
  return showGlassSheet<GoogleAccount>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
            child: Text(
              'Pilih akun Google',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Simulasi lokal, belum terhubung ke Google. Daftar ini hanya untuk menguji alur.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                for (final account in _testAccounts)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.12,
                      ),
                      child: Text(
                        account.name[0],
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(account.name),
                    subtitle: Text(account.email),
                    onTap: () => Navigator.of(ctx).pop(account),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
