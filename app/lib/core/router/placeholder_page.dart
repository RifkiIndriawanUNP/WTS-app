import 'package:flutter/material.dart';
import 'package:wts/shared/widgets/app_icons.dart';
import 'package:wts/shared/widgets/common_widgets.dart';
import 'package:wts/shared/widgets/glass.dart';

/// Halaman sementara untuk tab milik anggota tim lain (Home, Profil).
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.icon,
    required this.note,
  });

  final String title;
  final WtsIcon icon;
  final String note;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            GlassHeader(title: title),
            Expanded(
              child: EmptyState(
                icon: icon,
                title: '$title (placeholder)',
                message: note,
              ),
            ),
            SizedBox(height: navSpace(context)),
          ],
        ),
      ),
    );
  }
}
