import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wts/core/session/session.dart';
import 'package:wts/features/chat/data/fake_dm_repository.dart';
import 'package:wts/features/chat/domain/dm.dart';

/// Sementara memakai repository palsu. Nanti diganti implementasi Supabase.
final dmRepositoryProvider = Provider<DmRepository>(
  (ref) => FakeDmRepository(meId: ref.read(currentUserProvider).id),
);

final dmConversationsProvider = StreamProvider<List<DmConversation>>(
  (ref) => ref.watch(dmRepositoryProvider).watchConversations(),
);

final dmConversationProvider =
    StreamProvider.family<DmConversation?, String>(
  (ref, id) => ref.watch(dmRepositoryProvider).watchConversation(id),
);
