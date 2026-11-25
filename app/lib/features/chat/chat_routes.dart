import 'package:go_router/go_router.dart';
import 'package:wts/core/router/navigator_keys.dart';
import 'package:wts/features/chat/presentation/chat_list_page.dart';
import 'package:wts/features/chat/presentation/dm_room_page.dart';
import 'package:wts/features/chat/presentation/market_chat_room_page.dart';

/// Rute fitur Chat: daftar (tab), ruang chat market, ruang DM.
final List<RouteBase> chatRoutes = [
  GoRoute(
    path: '/chat',
    builder: (context, state) => const ChatListPage(),
    routes: [
      GoRoute(
        path: 'market/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            MarketChatRoomPage(chatId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: 'dm/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            DmRoomPage(conversationId: state.pathParameters['id']!),
      ),
    ],
  ),
];
