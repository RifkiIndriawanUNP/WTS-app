/// Rentang waktu terbit untuk filter linimasa.
enum PostTimeRange {
  all('Semua', null),
  day('24 jam', Duration(hours: 24)),
  week('7 hari', Duration(days: 7)),
  month('30 hari', Duration(days: 30));

  const PostTimeRange(this.label, this.window);

  final String label;

  /// Null = tanpa batas waktu.
  final Duration? window;
}

/// Filter tambahan feed Home (di luar tag dan urutan).
class PostFilter {
  const PostFilter({
    this.range = PostTimeRange.all,
    this.onlyWithImages = false,
    this.hideClosed = false,
  });

  final PostTimeRange range;
  final bool onlyWithImages;

  /// Sembunyikan postingan yang sudah ditandai "Selesai".
  final bool hideClosed;

  bool get isActive => activeCount > 0;

  /// Jumlah pengaturan filter yang aktif (untuk penanda di tombol Filter).
  int get activeCount =>
      (range != PostTimeRange.all ? 1 : 0) +
      (onlyWithImages ? 1 : 0) +
      (hideClosed ? 1 : 0);

  PostFilter copyWith({
    PostTimeRange? range,
    bool? onlyWithImages,
    bool? hideClosed,
  }) {
    return PostFilter(
      range: range ?? this.range,
      onlyWithImages: onlyWithImages ?? this.onlyWithImages,
      hideClosed: hideClosed ?? this.hideClosed,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PostFilter &&
      other.range == range &&
      other.onlyWithImages == onlyWithImages &&
      other.hideClosed == hideClosed;

  @override
  int get hashCode => Object.hash(range, onlyWithImages, hideClosed);
}
