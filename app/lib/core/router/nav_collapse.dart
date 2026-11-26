import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Status navigasi bawah: `true` = menyusut jadi lingkaran (saat halaman
/// di-scroll ke bawah), `false` = kapsul penuh.
///
/// Halaman mana pun boleh mengubahnya lewat [NavCollapsedNotifier.set]
/// (saat ini dipakai Market). MainShell yang menggambar animasinya.
class NavCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state != value) state = value;
  }
}

final navCollapsedProvider =
    NotifierProvider<NavCollapsedNotifier, bool>(NavCollapsedNotifier.new);

const double kNavHeight = 62;
const double kNavCircle = 56;
const double kNavSideGap = 20;
const double kNavCollapsedLeft = 28;

/// Jarak dasar kapsul navigasi dari tepi bawah layar.
double navBottomGap(BuildContext context) =>
    12 + MediaQuery.paddingOf(context).bottom;

/// Jarak bawah lingkaran saat menyusut: pusatnya sejajar dengan pusat kapsul.
double navCircleBottom(BuildContext context) =>
    navBottomGap(context) + (kNavHeight - kNavCircle) / 2;