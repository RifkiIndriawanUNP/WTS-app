import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wts/shared/models/app_user.dart';

/// Pengguna yang sedang login. Sementara tetap (data palsu);
/// nanti diganti dari sesi Supabase Auth + profiles_public.
final currentUserProvider = Provider<AppUser>((ref) => kFakeUsers[kMeId]!);
