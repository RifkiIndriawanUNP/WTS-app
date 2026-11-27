import 'package:go_router/go_router.dart';

import 'domain/post.dart';
import 'presentation/screens/post_detail_screen.dart';
import 'presentation/screens/post_form_screen.dart';
import 'presentation/screens/post_search_screen.dart';

/// Path layar linimasa di luar tab Home. Dipasang A ke router utama:
/// `routes: [...timelineRoutes, ...]`.
abstract final class TimelineRoutes {
  static const String compose = '/post/new';
  static const String edit = '/post/edit';
  static const String detail = '/posts/:id';
  static const String search = '/search';

  /// Path detail untuk id tertentu: `context.push(TimelineRoutes.detailPath(id))`.
  static String detailPath(String postId) => '/posts/$postId';
}

final List<RouteBase> timelineRoutes = [
  GoRoute(
    path: TimelineRoutes.search,
    builder: (context, state) => const PostSearchScreen(),
  ),
  GoRoute(
    path: TimelineRoutes.compose,
    builder: (context, state) => const PostFormScreen(),
  ),
  // Ubah postingan: kirim Post lewat `extra` -> context.push(TimelineRoutes.edit, extra: post)
  GoRoute(
    path: TimelineRoutes.edit,
    builder: (context, state) => PostFormScreen(editing: state.extra! as Post),
  ),
  // Detail postingan; Post (bila ada) lewat `extra` agar langsung tampil.
  GoRoute(
    path: TimelineRoutes.detail,
    builder: (context, state) => PostDetailScreen(
      postId: state.pathParameters['id']!,
      initial: state.extra as Post?,
    ),
  ),
];
