import 'package:flutter/widgets.dart';

/// Navigator paling atas. Halaman detail/ruang chat memakai key ini
/// (parentNavigatorKey) agar tampil layar penuh tanpa navigasi bawah.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
