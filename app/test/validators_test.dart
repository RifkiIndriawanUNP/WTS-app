import 'package:flutter_test/flutter_test.dart';
import 'package:wts/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('menerima email kampus', () {
      expect(Validators.email('fajar@nusaputra.ac.id'), isNull);
      expect(Validators.email('  Fajar.K@NusaPutra.ac.id '), isNull);
    });

    test('menolak kosong, format salah, dan domain lain', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('fajar'), isNotNull);
      expect(Validators.email('fajar@gmail.com'), isNotNull);
      expect(Validators.email('fajar@mail.nusaputra.ac.id'), isNotNull);
      expect(Validators.email('a@evil.com@nusaputra.ac.id'), isNotNull);
    });
  });

  group('Validators.username (^[a-z0-9_]{3,20}\$)', () {
    test('menerima username valid', () {
      expect(Validators.username('fajar_k'), isNull);
      expect(
        Validators.username('Fajar_22'),
        isNull,
      ); // dinormalkan ke huruf kecil
      expect(Validators.username('_ab'), isNull);
    });

    test('menolak terlalu pendek/panjang dan karakter lain', () {
      expect(Validators.username('ab'), isNotNull);
      expect(Validators.username('a' * 21), isNotNull);
      expect(Validators.username('fajar.k'), isNotNull);
      expect(Validators.username('fa jar'), isNotNull);
      expect(Validators.username(''), isNotNull);
    });
  });

  group('Validators.bio', () {
    test('maksimal 160 karakter', () {
      expect(Validators.bio(null), isNull);
      expect(Validators.bio('x' * 160), isNull);
      expect(Validators.bio('x' * 161), isNotNull);
    });
  });

  test('isAllowedImagePath', () {
    expect(Validators.isAllowedImagePath('/a/b/foto.JPG'), isTrue);
    expect(Validators.isAllowedImagePath('/a/b/foto.webp'), isTrue);
    expect(Validators.isAllowedImagePath('/a/b/foto.gif'), isFalse);
    expect(Validators.isAllowedImagePath('/a/b/foto'), isFalse);
  });
}
