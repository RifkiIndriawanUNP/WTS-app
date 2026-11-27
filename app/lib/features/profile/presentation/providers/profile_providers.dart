import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/fake_profile_repository.dart';
import '../../data/profile_repository.dart';
import '../../domain/public_profile.dart';

/// Sementara repo palsu; ganti dengan implementasi Supabase saat integrasi.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => FakeProfileRepository(
    currentUser: () => ref.read(authControllerProvider).user,
  ),
);

/// Profil pengguna lain menurut username. Dimuat ulang dengan `ref.invalidate`.
final publicProfileProvider = FutureProvider.autoDispose
    .family<PublicProfile, String>(
      (ref, username) =>
          ref.read(profileRepositoryProvider).fetchProfile(username),
    );
