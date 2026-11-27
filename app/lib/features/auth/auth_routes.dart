import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'presentation/screens/account_restricted_screen.dart';
import 'presentation/screens/intro_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/otp_screen.dart';
import 'presentation/screens/profile_setup_screen.dart';
import 'presentation/screens/splash_screen.dart';

/// Path layar autentikasi. `home` hanyalah tujuan setelah masuk; router
/// utama (milik A) memetakannya ke tab Home.
abstract final class AuthRoutes {
  static const String splash = '/';
  static const String intro = '/intro';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String setupProfile = '/setup-profile';
  static const String restricted = '/account-restricted';
  static const String home = '/home';
}

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondary, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// Dipasang A ke router utama: `routes: [...authRoutes, ...]`.
final List<RouteBase> authRoutes = [
  GoRoute(
    path: AuthRoutes.splash,
    pageBuilder: (c, s) => _fade(s, const SplashScreen()),
  ),
  GoRoute(
    path: AuthRoutes.intro,
    pageBuilder: (c, s) => _fade(s, const IntroScreen()),
  ),
  GoRoute(
    path: AuthRoutes.login,
    pageBuilder: (c, s) => _fade(s, const LoginScreen()),
  ),
  GoRoute(
    path: AuthRoutes.otp,
    pageBuilder: (c, s) => _fade(s, const OtpScreen()),
  ),
  GoRoute(
    path: AuthRoutes.setupProfile,
    pageBuilder: (c, s) => _fade(s, const ProfileSetupScreen()),
  ),
  GoRoute(
    path: AuthRoutes.restricted,
    pageBuilder: (c, s) => _fade(s, const AccountRestrictedScreen()),
  ),
];
