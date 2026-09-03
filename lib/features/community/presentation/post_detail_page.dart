import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/community_models.dart';
import 'community_controller.dart';
import 'community_widgets.dart';

class PostDetailPage extends ConsumerStatefulWidget {
  const PostDetailPage({required this.postId, super.key});

  final int postId;

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final _commentController = TextEditingController();
  CommunityComment? _replyingTo;
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(communityPostProvider(widget.postId));
    ref.invalidate(communityCommentsProvider(widget.postId));
    await Future.wait([
      ref.read(communityPostProvider(widget.postId).future),
      ref.read(communityCommentsProvider(widget.postId).future),
    ]);
  }

  Future<void> _submitComment() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) {
      context.go(AppRoutePaths.login);
      return;
    }
    final content = _commentController.text.trim();
    if (content.isEmpty) {
      _showMessage('请输入评论内容');
      return;
    }
    if (content.length > 1000) {
      _showMessage('评论不能超过1000个字符');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(communityRepositoryProvider)
          .createComment(
            widget.postId,
            content: content,
            parentId: _replyingTo?.id,
          );
      _commentController.clear();
      setState(() => _replyingTo = null);
      ref.invalidate(communityCommentsProvider(widget.postId));
      ref.invalidate(communityPostProvider(widget.postId));
      _showMessage('评论已发布');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('评论发布失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(communityPostProvider(widget.postId));
    final comments = ref.watch(communityCommentsProvider(widget.postId));
    final baseUrl = ref.watch(appConfigProvider).baseUrl;

    return Scaffold(
      backgroundColor: CommunityColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('帖子详情'),
        leading: IconButton(
          onPressed: () => context.go(AppRoutePaths.community),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: post.when(
                      loading: () => const SizedBox(
                        height: 260,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, _) => _ErrorCard(
                        message: error is ApiException
                            ? error.message
                            : '帖子加载失败',
                        onRetry: () => ref.invalidate(
                          communityPostProvider(widget.postId),
                        ),
                      ),
                      data: (value) => _PostBody(post: value, baseUrl: baseUrl),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: _CommentComposer(
                      controller: _commentController,
                      replyingTo: _replyingTo,
                      submitting: _submitting,
                      onCancelReply: () => setState(() => _replyingTo = null),
                      onSubmit: _submitComment,
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
              sliver: comments.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (error, _) => SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: _ErrorCard(
                        message: error is ApiException
                            ? error.message
                            : '评论加载失败',
                        onRetry: () => ref.invalidate(
                          communityCommentsProvider(widget.postId),
                        ),
                      ),
                    ),
                  ),
                ),
                data: (page) {
                  if (page.records.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(36),
                        child: Center(child: Text('还没有评论，来说说你的想法吧')),
                      ),
                    );
                  }
                  final names = {
                    for (final comment in page.records)
                      comment.id: comment.authorName,
                  };
                  return SliverList.separated(
                    itemCount: page.records.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final comment = page.records[index];
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 920),
                          child: _CommentCard(
                            comment: comment,
                            parentAuthor: comment.parentId == null
                                ? null
                                : names[comment.parentId],
                            baseUrl: baseUrl,
                            onReply: () {
                              setState(() => _replyingTo = comment);
                              _commentController.selection =
                                  TextSelection.collapsed(
                                    offset: _commentController.text.length,
                                  );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostBody extends StatelessWidget {
  const _PostBody({required this.post, required this.baseUrl});

  final CommunityPost post;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: CommunityColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CommunityAvatar(
                  name: post.authorName,
                  avatar: post.authorAvatar,
                  baseUrl: baseUrl,
                  radius: 23,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        communityTime(post.createTime),
                        style: const TextStyle(
                          color: CommunityColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 27,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            SelectableText(
              post.content,
              style: const TextStyle(fontSize: 16, height: 1.8),
            ),
            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 22),
              _PostGallery(imageUrls: post.imageUrls, baseUrl: baseUrl),
            ],
            if (post.books.isNotEmpty) ...[
              const SizedBox(height: 20),
              CommunityBookChips(books: post.books),
            ],
          ],
        ),
      ),
    );
  }
}

class _PostGallery extends StatelessWidget {
  const _PostGallery({required this.imageUrls, required this.baseUrl});

  final List<String> imageUrls;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 390,
      child: PageView.builder(
        itemCount: imageUrls.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: communityMediaUrl(baseUrl, imageUrls[index]),
              fit: BoxFit.contain,
              placeholder: (_, _) => const ColoredBox(
                color: CommunityColors.softAccent,
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, _, _) => const ColoredBox(
                color: CommunityColors.softAccent,
                child: Center(
                  child: Icon(Icons.broken_image_outlined, size: 42),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.replyingTo,
    required this.submitting,
    required this.onCancelReply,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final CommunityComment? replyingTo;
  final bool submitting;
  final VoidCallback onCancelReply;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: CommunityColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (replyingTo != null)
              Row(
                children: [
                  Expanded(child: Text('回复 ${replyingTo!.authorName}')),
                  IconButton(
                    onPressed: onCancelReply,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 5,
              maxLength: 1000,
              decoration: const InputDecoration(
                hintText: '友善交流，分享你的阅读想法…',
                border: OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: submitting ? null : onSubmit,
                icon: submitting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(submitting ? '发布中' : '发表评论'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.comment,
    required this.parentAuthor,
    required this.baseUrl,
    required this.onReply,
  });

  final CommunityComment comment;
  final String? parentAuthor;
  final String baseUrl;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: comment.isReply ? 34 : 0),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: CommunityColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CommunityAvatar(
                name: comment.authorName,
                avatar: comment.authorAvatar,
                baseUrl: baseUrl,
                radius: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      children: [
                        Text(
                          comment.authorName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (parentAuthor != null)
                          Text(
                            '回复 @$parentAuthor',
                            style: const TextStyle(
                              color: CommunityColors.accent,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(comment.content, style: const TextStyle(height: 1.55)),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Text(
                          communityTime(comment.createTime),
                          style: const TextStyle(
                            color: CommunityColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: onReply,
                          icon: const Icon(Icons.reply_rounded, size: 17),
                          label: const Text('回复'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 38),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('重新加载')),
          ],
        ),
      ),
    );
  }
}
