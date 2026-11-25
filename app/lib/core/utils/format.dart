import 'package:flutter/services.dart';

String _group(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// 145000 -> "Rp145.000" (titik pemisah ribuan, tanpa desimal).
String formatRp(num value) => 'Rp${_group(value.round().abs().toString())}';

/// 145000 -> "145.000"
String formatThousands(int value) => _group(value.abs().toString());

/// "145.000" -> 145000 (null jika kosong).
int? parseRupiah(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

/// Memformat input harga otomatis: 10000 -> 10.000 (hanya angka bulat).
class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    digits = digits.replaceFirst(RegExp(r'^0+'), '');
    if (digits.length > 9) digits = digits.substring(0, 9);
    final text = _group(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String clock(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

String dateShort(DateTime t) => '${t.day} ${_months[t.month - 1]} ${t.year}';

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String dayLabel(DateTime t) {
  final now = DateTime.now();
  if (sameDay(t, now)) return 'Hari ini';
  if (sameDay(t, now.subtract(const Duration(days: 1)))) return 'Kemarin';
  return dateShort(t);
}

/// Waktu singkat untuk daftar chat: jam / Kemarin / tanggal.
String listTime(DateTime t) {
  final now = DateTime.now();
  if (sameDay(t, now)) return clock(t);
  if (sameDay(t, now.subtract(const Duration(days: 1)))) return 'Kemarin';
  return '${t.day} ${_months[t.month - 1]}';
}

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'Baru saja';
  if (d.inMinutes < 60) return '${d.inMinutes} mnt lalu';
  if (d.inHours < 24) return '${d.inHours} jam lalu';
  if (d.inDays < 7) return '${d.inDays} hari lalu';
  return dateShort(t);
}

/// Sisa waktu menuju [until], mis. "2 hari 5 jam".
String remaining(DateTime until) {
  final d = until.difference(DateTime.now());
  if (d.isNegative || d.inMinutes < 1) return 'kurang dari 1 menit';
  if (d.inDays >= 1) {
    final h = d.inHours - d.inDays * 24;
    return h > 0 ? '${d.inDays} hari $h jam' : '${d.inDays} hari';
  }
  if (d.inHours >= 1) {
    final m = d.inMinutes - d.inHours * 60;
    return m > 0 ? '${d.inHours} jam $m mnt' : '${d.inHours} jam';
  }
  return '${d.inMinutes} menit';
}
