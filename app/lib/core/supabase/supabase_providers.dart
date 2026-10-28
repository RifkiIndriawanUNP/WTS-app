import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Satu-satunya tempat mengambil client Supabase.
/// Layar/widget jangan memanggil Supabase langsung; lewat repository.
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
