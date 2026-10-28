import 'package:flutter_test/flutter_test.dart';
import 'package:wts/core/supabase/failure.dart';

// Tes bawaan Flutter (counter) diganti tes sederhana ini karena app sudah berubah.
// Tes ini tidak membutuhkan koneksi Supabase.
void main() {
  test('mapError memberi pesan ramah untuk error tidak dikenal', () {
    final failure = mapError(Exception('apa saja'));
    expect(failure.code, 'unknown');
    expect(failure.message, isNotEmpty);
  });
}
