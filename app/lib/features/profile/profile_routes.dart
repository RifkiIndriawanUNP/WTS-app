import 'package:go_router/go_router.dart';

import 'presentation/screens/profile_screen.dart';

/// Route fitur Profil. Tab Profil (milik sendiri) cukup memakai
/// `ProfileScreen()` sebagai isi tab; route ini untuk profil orang lain.
class ProfileRoutes {
  ProfileRoutes._();

  static const String user = '/u/:username';
  static String userPath(String username) => '/u/$username';
}

final List<RouteBase> profileRoutes = [
  GoRoute(
    path: ProfileRoutes.user,
    builder: (context, state) => ProfileScreen(
      username: state.pathParameters['username'],
      showBack: true,
    ),
  ),
];
