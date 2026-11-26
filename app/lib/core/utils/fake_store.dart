import 'dart:async';

/// Pengganti Realtime Supabase untuk repository palsu: setiap perubahan data
/// memanggil [notify], dan semua stream dari [watch] memancarkan data terbaru.
class FakeStore {
  final StreamController<void> _changes = StreamController<void>.broadcast();

  void notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Stream<T> watch<T>(
    T Function() read, {
    Duration initialDelay = Duration.zero,
  }) async* {
    if (initialDelay > Duration.zero) {
      await Future<void>.delayed(initialDelay);
    }
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }
}

/// Pembatas laju sederhana (mis. 30 pesan/menit).
class RateLimiter {
  RateLimiter(this.max, this.window);

  final int max;
  final Duration window;
  final List<DateTime> _hits = [];

  bool tryHit() {
    final now = DateTime.now();
    _hits.removeWhere((t) => now.difference(t) > window);
    if (_hits.length >= max) return false;
    _hits.add(now);
    return true;
  }
}
