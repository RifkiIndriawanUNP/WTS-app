import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:wts/core/theme/app_theme.dart';

/// Ruang kosong di bawah daftar agar tidak tertutup navigasi bawah melayang.
double navSpace(BuildContext context) =>
    96 + MediaQuery.paddingOf(context).bottom;

/// Latar gradien lembut dengan "blob" cahaya agar efek kaca terlihat.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDCE8FF), Color(0xFFF4F7FF), Color(0xFFE6EEFF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: _blob(300, AppColors.primary.withValues(alpha: .30)),
          ),
          Positioned(
            top: 280,
            left: -140,
            child: _blob(320, const Color(0xFF7DD3FC).withValues(alpha: .38)),
          ),
          Positioned(
            bottom: -110,
            right: -60,
            child: _blob(320, const Color(0xFFA5B4FC).withValues(alpha: .38)),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

/// Scaffold transparan di atas [GlassBackground].
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    super.key,
    required this.body,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final Widget? floatingActionButton;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        floatingActionButton: floatingActionButton,
        body: body,
      ),
    );
  }
}

/// Kartu kaca: blur + isi putih tembus pandang + tepi terang.
/// Set [blur] = 0 untuk daftar panjang agar tetap ringan.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 22,
    this.onTap,
    this.onLongPress,
    this.blur = 14,
    this.opacity = .62,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double blur;
  final double opacity;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    Widget inner = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        color: (tint ?? Colors.white).withValues(alpha: opacity),
        border: Border.all(color: Colors.white.withValues(alpha: .8)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: shape,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    if (blur > 0) {
      inner = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: inner,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .08),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: shape, child: inner),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: active
          ? AppColors.primary
          : Colors.white.withValues(alpha: .72),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: .9)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 20,
            color: active ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Header halaman (pengganti AppBar).
class GlassHeader extends StatelessWidget {
  const GlassHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.onBack,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          if (onBack != null) ...[
            GlassIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: onBack,
            ),
            const SizedBox(width: 12),
          ],
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: 8), a],
        ],
      ),
    );
  }
}

/// Pembungkus bottom sheet bergaya kaca.
class GlassSheet extends StatelessWidget {
  const GlassSheet({super.key, required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          color: Colors.white.withValues(alpha: .88),
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            32 +
                MediaQuery.viewInsetsOf(context).bottom +
                MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (title != null) ...[
                Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}