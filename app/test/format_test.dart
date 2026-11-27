import 'package:flutter_test/flutter_test.dart';
import 'package:wts/core/utils/format.dart';

void main() {
  group('Fmt.count', () {
    test('angka kecil apa adanya', () {
      expect(Fmt.count(0), '0');
      expect(Fmt.count(999), '999');
      expect(Fmt.count(-5), '-5');
    });

    test('ribuan dipendekkan dengan koma desimal', () {
      expect(Fmt.count(1000), '1rb');
      expect(Fmt.count(1500), '1,5rb');
      expect(Fmt.count(10500), '10,5rb');
      expect(Fmt.count(-2300), '-2,3rb');
    });
  });

  group('Fmt.relative', () {
    final now = DateTime(2026, 11, 13, 12, 0);

    test('menit, jam, hari', () {
      expect(Fmt.relative(now, now: now), 'baru saja');
      expect(
        Fmt.relative(now.subtract(const Duration(minutes: 5)), now: now),
        '5 mnt',
      );
      expect(
        Fmt.relative(now.subtract(const Duration(hours: 3)), now: now),
        '3 jam',
      );
      expect(
        Fmt.relative(now.subtract(const Duration(days: 2)), now: now),
        '2 hari',
      );
    });

    test('lebih dari seminggu menjadi tanggal', () {
      expect(Fmt.relative(DateTime(2026, 11, 1), now: now), '1 Nov');
    });
  });

  test('Fmt.remaining', () {
    expect(Fmt.remaining(const Duration(minutes: 20)), '20 mnt lagi');
    expect(Fmt.remaining(const Duration(hours: 5)), '5 jam lagi');
    expect(Fmt.remaining(const Duration(days: 3)), '3 hari lagi');
  });
}
