import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../comments/data/comment_repository.dart';
import '../../../comments/domain/comment.dart';
import '../../../comments/presentation/providers/comment_providers.dart';
import '../../../comments/presentation/widgets/comment_composer.dart';
import '../../../comments/presentation/widgets/comment_menu_sheet.dart';
import '../../../comments/presentation/widgets/comment_tree.dart';
import '../../../moderation/domain/report.dart';
import '../../../profile/presentation/profile_navigation.dart';
import '../../../moderation/presentation/widgets/report_sheet.dart';
import '../../data/post_repository.dart';
import '../../domain/post.dart';
import '../providers/feed_providers.dart';
import '../widgets/feed_states.dart';
import '../widgets/image_viewer.dart';
import '../widgets/post_actions.dart';
import '../widgets/post_card.dart';
import '../widgets/post_card_skeleton.dart';
import '../widgets/post_share.dart';

/// Detail postingan + komentar. [initial] (bila ada) langsung ditampilkan
/// sementara data terbaru dimuat.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId, this.initial});

  final String postId;
  final Post? initial;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  Post? _post;
  String? _postError;

  List<Comment>? _comments;
  bool _commentsLoading = true;
  String? _commentsError;
  CommentSort _sort = CommentSort.best;

  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();
  final Set<String> _expanded = {};
  Comment? _replyTo;
  Comment? _editing;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _post = widget.initial;
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await Future.wait([_loadPost(), _loadComments()]);
  }

  Future<void> _loadPost() async {
    try {
      final fresh = await ref
          .read(postRepositoryProvider)
          .getPost(widget.postId);
      if (mounted) {
        setState(() {
          _post = fresh;
          _postError = null;
        });
      }
    } on PostException catch (e) {
      if (mounted) {
        setState(() {
          _postError = e.message;
          if (e.code == 'not_found') {
            _post = null;
          }
        });
      }
    }
  }

  Future<void> _loadComments() async {
    if (!_commentsLoading || _commentsError != null) {
      setState(() {
        _commentsLoading = true;
        _commentsError = null;
      });
    }
    try {
      final list = await ref
          .read(commentRepositoryProvider)
          .fetchComments(widget.postId);
      if (mounted) {
        setState(() {
          _comments = list;
          _commentsLoading = false;
        });
      }
    } on CommentException catch (e) {
      if (mounted) {
        setState(() {
          _commentsError = e.message;
          _commentsLoading = false;
        });
      }
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _votePost(int direction) async {
    final before = _post;
    if (before == null) {
      return;
    }
    if (before.isMine) {
      _snack('Kamu tidak bisa memberi suara pada postinganmu sendiri');
      return;
    }
    setState(
      () => _post = before.withVote(before.myVote == direction ? 0 : direction),
    );
    try {
      final server = await ref
          .read(feedControllerProvider.notifier)
          .toggleVote(before, direction);
      if (mounted) {
        setState(() => _post = server);
      }
    } on PostException catch (e) {
      if (mounted) {
        setState(() => _post = before);
        _snack(e.message);
      }
    }
  }

  Future<void> _savePost() async {
    final before = _post;
    if (before == null) {
      return;
    }
    setState(() => _post = before.copyWith(isSaved: !before.isSaved));
    try {
      final result = await ref
          .read(feedControllerProvider.notifier)
          .toggleSave(before);
      if (mounted) {
        setState(() => _post = result);
      }
    } on PostException catch (e) {
      if (mounted) {
        setState(() => _post = before);
        _snack(e.message);
      }
    }
  }

  Future<void> _menu(Post post) async {
    final result = await showPostActions(context, ref, post);
    if (!mounted) {
      return;
    }
    switch (result.outcome) {
      case PostActionOutcome.deleted:
        Navigator.of(context).pop();
      case PostActionOutcome.edited:
      case PostActionOutcome.closed:
        if (result.post != null) {
          setState(() => _post = result.post);
        }
      case PostActionOutcome.reported:
      case PostActionOutcome.none:
        break;
    }
  }

  Future<void> _voteComment(Comment comment, int direction) async {
    final list = _comments;
    if (list == null) {
      return;
    }
    int indexOf(String id) => list.indexWhere((c) => c.id == id);
    final i = indexOf(comment.id);
    if (i < 0) {
      return;
    }
    if (comment.isMine) {
      _snack('Kamu tidak bisa memberi suara pada komentarmu sendiri');
      return;
    }
    final before = list[i];
    final next = before.myVote == direction ? 0 : direction;
    setState(() => list[i] = before.withVote(next));
    try {
      final server = await ref
          .read(commentRepositoryProvider)
          .setVote(comment.id, next);
      if (mounted) {
        setState(() => list[indexOf(comment.id)] = server);
      }
    } on CommentException catch (e) {
      if (mounted) {
        setState(() => list[indexOf(comment.id)] = before);
        _snack(e.message);
      }
    }
  }

  void _startReply(Comment c) {
    setState(() {
      _replyTo = c;
      _editing = null;
      _input.clear();
    });
    _focus.requestFocus();
  }

  void _cancelMode() {
    setState(() {
      _replyTo = null;
      _editing = null;
      _input.clear();
    });
    _focus.unfocus();
  }

  void _bumpCount(int delta) {
    final p = _post;
    if (p != null) {
      _post = p.copyWith(
        commentCount: (p.commentCount + delta).clamp(0, 1 << 30),
      );
    }
    ref
        .read(feedControllerProvider.notifier)
        .patchCommentCount(widget.postId, delta);
  }

  Future<void> _send() async {
    final list = _comments;
    final text = _input.text;
    if (list == null || _sending || CommentRules.validateBody(text) != null) {
      return;
    }
    final repo = ref.read(commentRepositoryProvider);
    final editing = _editing;
    final reply = _replyTo;
    setState(() => _sending = true);
    try {
      if (editing != null) {
        final updated = await repo.editComment(editing.id, text);
        if (!mounted) {
          return;
        }
        setState(() {
          final i = list.indexWhere((c) => c.id == editing.id);
          if (i >= 0) {
            list[i] = updated;
          }
        });
      } else {
        final created = await repo.createComment(
          postId: widget.postId,
          body: text,
          parentId: reply?.id,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          list.add(created);
          // Buka rantai balasan di atasnya supaya komentar baru langsung terlihat.
          var parent = created.parentId;
          while (parent != null) {
            _expanded.add(parent);
            final i = list.indexWhere((c) => c.id == parent);
            parent = i < 0 ? null : list[i].parentId;
          }
          _bumpCount(1);
        });
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _replyTo = null;
        _editing = null;
        _input.clear();
      });
      _focus.unfocus();
    } on CommentException catch (e) {
      if (mounted) {
        _snack(e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _commentMenu(Comment c) async {
    final action = await showCommentMenu(context, c);
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case CommentMenuAction.edit:
        if (!c.canEdit(DateTime.now())) {
          _snack('Komentar hanya bisa diubah dalam 5 menit setelah dikirim');
          return;
        }
        setState(() {
          _editing = c;
          _replyTo = null;
          _input.text = c.body ?? '';
          _input.selection = TextSelection.collapsed(
            offset: _input.text.length,
          );
        });
        _focus.requestFocus();
      case CommentMenuAction.delete:
        await _deleteComment(c);
      case CommentMenuAction.report:
        final sent = await showReportSheet(
          context,
          target: ReportTarget.comment,
          targetId: c.id,
        );
        if (sent && mounted) {
          showReportSentSnack(context);
        }
    }
  }

  Future<void> _deleteComment(Comment c) async {
    final ok = await showGlassConfirm(
      context,
      title: 'Hapus komentar?',
      message: 'Komentar yang dihapus tidak bisa dikembalikan.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (ok != true || !mounted) {
      return;
    }
    try {
      final result = await ref
          .read(commentRepositoryProvider)
          .deleteComment(c.id);
      if (!mounted) {
        return;
      }
      final list = _comments;
      if (list == null) {
        return;
      }
      setState(() {
        final i = list.indexWhere((x) => x.id == c.id);
        if (i >= 0) {
          if (result == null) {
            list.removeAt(i);
            _bumpCount(-1);
          } else {
            list[i] = result;
          }
        }
        if (_replyTo?.id == c.id || _editing?.id == c.id) {
          _replyTo = null;
          _editing = null;
          _input.clear();
        }
      });
    } on CommentException catch (e) {
      if (mounted) {
        _snack(e.message);
      }
    }
  }

  Future<void> _pickSort() async {
    final picked = await showOptionPicker(
      context,
      title: 'Urutkan komentar',
      options: [for (final s in CommentSort.values) s.label],
      selected: _sort.label,
    );
    if (picked != null && mounted) {
      setState(
        () => _sort = CommentSort.values.firstWhere((s) => s.label == picked),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;

    return GlassScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Kembali',
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Text(
                    'Postingan',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            Expanded(child: _body(post)),
            if (post != null) _composer(post),
          ],
        ),
      ),
    );
  }

  Widget _composer(Post post) {
    final user = ref.watch(authControllerProvider.select((s) => s.user));
    return CommentComposer(
      controller: _input,
      focusNode: _focus,
      initials: user?.initials ?? '?',
      avatarPath: user?.avatarPath,
      closed: post.isClosed,
      sending: _sending,
      replyingTo: _replyTo?.authorLabel,
      editing: _editing != null,
      onSend: _send,
      onCancelMode: _cancelMode,
    );
  }

  Widget _body(Post? post) {
    if (post == null) {
      if (_postError != null) {
        return SingleChildScrollView(
          child: FeedError(message: _postError!, onRetry: _load),
        );
      }
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: PostCardSkeleton(),
      );
    }

    final theme = Theme.of(context);
    final comments = _comments;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          PostCard(
            post: post,
            expanded: true,
            onAuthorTap: post.authorUsername == null
                ? null
                : () => openUserProfile(context, post.authorUsername!),
            onVote: _votePost,
            onSave: _savePost,
            onShare: () => sharePost(context, post),
            onMenu: () => _menu(post),
            onImageTap: (i) =>
                showImageViewer(context, images: post.images, initialIndex: i),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Komentar${comments == null ? '' : ' ${comments.length}'}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (comments != null && comments.length > 1)
                TextButton.icon(
                  onPressed: _pickSort,
                  icon: const Icon(Icons.swap_vert_rounded, size: 18),
                  label: Text(_sort.label),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_commentsLoading && comments == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            )
          else if (_commentsError != null && comments == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Text(
                    _commentsError!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                  TextButton(
                    onPressed: _loadComments,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            )
          else if (comments == null || comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 40,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Belum ada komentar',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    post.isClosed
                        ? 'Komentar sudah ditutup.'
                        : 'Jadilah yang pertama berkomentar.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            CommentTree(
              nodes: buildCommentTree(comments, _sort),
              expanded: _expanded,
              onExpand: (id) => setState(() => _expanded.add(id)),
              onVote: _voteComment,
              onReply: post.isClosed ? null : _startReply,
              onMenu: _commentMenu,
            ),
        ],
      ),
    );
  }
}
