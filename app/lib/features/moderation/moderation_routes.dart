import 'package:go_router/go_router.dart';

import 'presentation/screens/report_detail_screen.dart';
import 'presentation/screens/report_queue_screen.dart';

/// Path layar moderasi (khusus moderator/admin). Dipasang A ke router utama:
/// `routes: [...moderationRoutes, ...]`. Guard peran juga dicek di layar dan
/// wajib di server (RLS).
abstract final class ModerationRoutes {
  static const String queue = '/moderation';
  static const String detail = '/moderation/:id';

  static String detailPath(String caseId) =>
      '/moderation/${Uri.encodeComponent(caseId)}';
}

final List<RouteBase> moderationRoutes = [
  GoRoute(
    path: ModerationRoutes.queue,
    builder: (context, state) => const ReportQueueScreen(),
  ),
  GoRoute(
    path: ModerationRoutes.detail,
    builder: (context, state) =>
        ReportDetailScreen(caseId: state.pathParameters['id'] ?? ''),
  ),
];
