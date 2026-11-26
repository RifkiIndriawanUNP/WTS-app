import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';

class WtsApp extends StatelessWidget {
  const WtsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WTS',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const SmokeTestScreen(),
    );
  }
}

/// Layar sementara untuk membuktikan: app -> Supabase -> database tersambung.
/// Akan diganti router + layar sungguhan oleh Lead.
class SmokeTestScreen extends StatefulWidget {
  const SmokeTestScreen({super.key});

  @override
  State<SmokeTestScreen> createState() => _SmokeTestScreenState();
}

class _SmokeTestScreenState extends State<SmokeTestScreen> {
  final _log = <String>[];
  final _db = Supabase.instance.client;

  void _add(String text) => setState(() => _log.add(text));

  Future<void> _run() async {
    setState(_log.clear);

    try {
      _add('ping: ${await _db.rpc('ping')}');
    } catch (e) {
      _add('ping GAGAL: $e');
    }

    if (Env.devLogin && _db.auth.currentSession == null) {
      try {
        await _db.auth.signInWithPassword(
          email: 'dev1@nusaputra.ac.id',
          password: 'Dev12345!',
        );
        _add('login dev1 OK');
      } catch (e) {
        _add('login GAGAL: $e');
      }
    }

    try {
      final tags = await _db.from('tags').select('name').eq('scope', 'timeline');
      _add('tag linimasa: ${tags.length} (harus 11)');
      final posts = await _db.from('posts_public').select('id').limit(1);
      _add('posts_public: OK (${posts.length} baris)');
    } catch (e) {
      _add('query GAGAL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WTS - uji koneksi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton(onPressed: _run, child: const Text('Jalankan uji')),
          const SizedBox(height: 12),
          for (final line in _log) Text(line),
        ],
      ),
    );
  }
}
