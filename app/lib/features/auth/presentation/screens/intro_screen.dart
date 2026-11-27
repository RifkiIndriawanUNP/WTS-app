import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth_routes.dart';
import '../../../../core/storage/app_prefs.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/widgets.dart';

class _Slide {
  const _Slide(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

const List<_Slide> _slides = [
  _Slide(
    Icons.storefront_rounded,
    'Jual beli barang kuliah',
    'Modul, jas lab, alat praktikum, sampai perlengkapan kos. Jual atau sewakan ke sesama mahasiswa Nusa Putra.',
  ),
  _Slide(
    Icons.forum_rounded,
    'Berbagi info kampus',
    'Cari responden kuesioner, umumkan kegiatan organisasi, atau tanya soal tugas. Mau anonim? Bisa.',
  ),
  _Slide(
    Icons.verified_user_rounded,
    'COD aman di kampus',
    'Hanya akun @nusaputra.ac.id yang bisa masuk. Bertemu langsung di kampus, tanpa pembayaran lewat aplikasi.',
  ),
];

/// Pengenalan WTS (tampil sekali pada pemakaian pertama).
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pages = PageController();
  int _index = 0;

  bool get _isLast => _index == _slides.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await AppPrefs.markIntroSeen();
    if (!mounted) {
      return;
    }
    context.go(AuthRoutes.login);
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _pages.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return GlassScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isLast ? 0 : 1,
                  child: TextButton(
                    onPressed: _isLast ? null : _finish,
                    child: const Text('Lewati'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GlassContainer(
                          radius: 80,
                          blur: 22,
                          child: SizedBox(
                            width: 156,
                            height: 156,
                            child: Icon(
                              slide.icon,
                              size: 72,
                              color: AppColors.brandBlue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 44),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          slide.body,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? AppColors.brandBlue
                          : scheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              child: GlassButton(
                label: _isLast ? 'Mulai' : 'Lanjut',
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
