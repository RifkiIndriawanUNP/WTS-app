/// Format tampilan angka dan waktu (Bahasa Indonesia).
abstract final class Fmt {
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static const List<String> _monthsLong = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  /// "13 November 2026".
  static String date(DateTime t) =>
      '${t.day} ${_monthsLong[t.month - 1]} ${t.year}';

  /// "baru saja", "5 mnt", "3 jam", "2 hari", lalu "12 Nov".
  static String relative(DateTime time, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(time);
    if (diff.inMinutes < 1) {
      return 'baru saja';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} mnt';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} jam';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} hari';
    }
    return '${time.day} ${_months[time.month - 1]}';
  }

  /// "baru saja", "5 mnt lalu", "3 jam lalu", "2 hari lalu", lalu "12 Nov".
  static String ago(DateTime time, {DateTime? now}) {
    final r = relative(time, now: now);
    final diff = (now ?? DateTime.now()).difference(time);
    return (diff.inMinutes < 1 || diff.inDays >= 7) ? r : '$r lalu';
  }

  /// Sisa waktu: "20 mnt lagi", "5 jam lagi", "3 hari lagi".
  static String remaining(Duration d) {
    if (d.inMinutes < 60) {
      return '${d.inMinutes < 1 ? 1 : d.inMinutes} mnt lagi';
    }
    if (d.inHours < 24) {
      return '${d.inHours} jam lagi';
    }
    return '${d.inDays} hari lagi';
  }

  /// 999 -> "999", 1500 -> "1,5rb", -2300 -> "-2,3rb".
  static String count(int n) {
    final abs = n.abs();
    if (abs < 1000) {
      return '$n';
    }
    final fixed = (abs / 1000).toStringAsFixed(1);
    final text = fixed.endsWith('.0')
        ? fixed.substring(0, fixed.length - 2)
        : fixed.replaceAll('.', ',');
    return '${n < 0 ? '-' : ''}${text}rb';
  }
}
