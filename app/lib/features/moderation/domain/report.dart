/// Jenis konten yang bisa dilaporkan (enum report_target di database).
enum ReportTarget {
  post('postingan'),
  comment('komentar'),
  product('barang'),
  user('akun'),
  message('pesan');

  const ReportTarget(this.label);
  final String label;
}

/// Alasan laporan (enum report_reason di database).
enum ReportReason {
  spam('Spam atau promosi berlebihan'),
  hate('Ujaran kebencian atau SARA'),
  harassment('Perundungan atau pelecehan'),
  adult('Konten dewasa'),
  scam('Penipuan'),
  prohibitedItem('Barang atau jasa terlarang'),
  misinformation('Informasi palsu'),
  privacy('Melanggar privasi orang lain'),
  other('Lainnya');

  const ReportReason(this.label);
  final String label;

  /// Nilai enum di database (snake_case).
  String get dbValue => switch (this) {
    ReportReason.prohibitedItem => 'prohibited_item',
    _ => name,
  };
}

abstract final class ReportRules {
  static const int noteMax = 500;
}
