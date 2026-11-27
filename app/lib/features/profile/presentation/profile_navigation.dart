import 'package:flutter/material.dart';

import 'screens/profile_screen.dart';

/// Buka profil seorang pengguna lewat Navigator. A dapat menggantinya dengan
/// `context.push(ProfileRoutes.userPath(username))`.
void openUserProfile(BuildContext context, String username) {
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ProfileScreen(username: username, showBack: true),
    ),
  );
}
