import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_route_paths.dart';
import '../../community/data/community_models.dart';
import 'admin_page.dart';
import 'admin_providers.dart';

String adminCommunityPostStatusLabel(int status) => status == 1 ? '正常' : '已屏蔽';

String adminCommunityPostActionLabel(int status) => status == 1 ? '屏蔽' : '恢复';

class AdminCommunityPostsPage extends ConsumerStatefulWidget {
  const AdminCommunityPostsPage({super.key});

  @override
  ConsumerState<AdminCommunityPostsPage> createState() =>
      _AdminCommunityPostsPageState();
}

class _AdminCommunityPostsPageState
    extends ConsumerState<AdminCommunityPostsPage> {
  final _keywordController = TextEditingController();
  final _userController = TextEditingController();
  final Set<int> _changingPostIds = <int>{};

  String? _keyword;
  int? _userId;
  int? _status;
  int _page = 1;

  AdminCommunityPostFilter get _filter =>
      (keyword: _keyword, userId: _userId, status: _status, page: _page);

  @override
  void dispose() {
    _keywordController.dispose();
    _userController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminCommunityPostsProvider(_filter));
    return AdminPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilters(),
          const SizedBox(height: 16),
          AdminPanel(
            padding: EdgeInsets.zero,
            child: AdminAsync(
              value: value,
              retry: _refresh,
              data: (response) {
                if (response.records.isEmpty) {
                  return const _CommunityPostsEmpty();
                }
                return Column(
                  children: [
                    for (
                      var index = 0;
                      index < response.records.length;
                      index++
                    ) ...[
                      _CommunityPostItem(
                        post: response.records[index],
                        changing: _changingPostIds.contains(
                          response.records[index].id,
                        ),
                        onView: response.records[index].status == 1
                            ? () => context.go(
                                AppRoutePaths.communityPost(
                                  response.records[index].id,
                                ),
                              )
                            : null,
                        onToggle: () => _toggle(response.records[index]),
                      ),
                      if (index != response.records.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                );
              },
            ),
          ),
          value.when(
            data: (response) => AdminPagination(
              page: response,
              onPage: (page) => setState(() => _page = page),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      const SizedBox(
        width: 240,
        child: Text(
          '帖子管理',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
      ),
      SizedBox(
        width: 240,
        child: TextField(
          controller: _keywordController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _apply(),
          decoration: const InputDecoration(
            labelText: '标题关键词',
            prefixIcon: Icon(Icons.search),
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
      ),
      SizedBox(
        width: 150,
        child: TextField(
          controller: _userController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _apply(),
          decoration: const InputDecoration(
            labelText: '发布用户 ID',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
      ),
      DropdownButton<int?>(
        value: _status,
        items: const [
          DropdownMenuItem(value: null, child: Text('全部帖子')),
          DropdownMenuItem(value: 1, child: Text('正常')),
          DropdownMenuItem(value: 0, child: Text('已屏蔽')),
        ],
        onChanged: (value) => setState(() {
          _status = value;
          _page = 1;
        }),
      ),
      FilledButton.icon(
        onPressed: _apply,
        icon: const Icon(Icons.filter_alt_outlined, size: 18),
        label: const Text('查询'),
      ),
      IconButton(
        tooltip: '重置筛选',
        onPressed: _reset,
        icon: const Icon(Icons.filter_alt_off_outlined),
      ),
      IconButton(
        tooltip: '刷新',
        onPressed: _refresh,
        icon: const Icon(Icons.refresh),
      ),
    ],
  );

  void _apply() {
    final rawUserId = _userController.text.trim();
    final parsedUserId = rawUserId.isEmpty ? null : int.tryParse(rawUserId);
    if (rawUserId.isNotEmpty && (parsedUserId == null || parsedUserId <= 0)) {
      showAdminMessage(context, '发布用户 ID 必须是正整数');
      return;
    }
    setState(() {
      final keyword = _keywordController.text.trim();
      _keyword = keyword.isEmpty ? null : keyword;
      _userId = parsedUserId;
      _page = 1;
    });
  }

  void _reset() {
    _keywordController.clear();
    _userController.clear();
    setState(() {
      _keyword = null;
      _userId = null;
      _status = null;
      _page = 1;
    });
  }

  void _refresh() => ref.invalidate(adminCommunityPostsProvider(_filter));

  Future<void> _toggle(CommunityPost post) async {
    final nextStatus = post.status == 1 ? 0 : 1;
    final action = adminCommunityPostActionLabel(post.status);
    final confirmed = await confirmAdminAction(
      context,
      title: '$action帖子',
      message: nextStatus == 0
          ? '屏蔽后普通用户将无法在社区列表和详情中看到该帖子，确定继续吗？'
          : '恢复后该帖子将重新对普通用户可见，确定继续吗？',
    );
    if (!confirmed || !mounted) return;

    setState(() => _changingPostIds.add(post.id));
    try {
      await ref
          .read(adminRepositoryProvider)
          .setCommunityPostStatus(post.id, nextStatus);
      if (!mounted) return;
      showAdminMessage(context, '帖子已${nextStatus == 0 ? '屏蔽' : '恢复'}');
      _refresh();
    } catch (error) {
      if (mounted) showAdminMessage(context, error);
    } finally {
      if (mounted) setState(() => _changingPostIds.remove(post.id));
    }
  }
}

class _CommunityPostItem extends StatelessWidget {
  const _CommunityPostItem({
    required this.post,
    required this.changing,
    required this.onToggle,
    this.onView,
  });

  final CommunityPost post;
  final bool changing;
  final VoidCallback? onView;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFE8EFEA),
              child: Text(
                post.authorName.isEmpty
                    ? '读'
                    : post.authorName.characters.first,
                style: const TextStyle(
                  color: AdminColors.green,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AdminColors.ink,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${post.authorName} · 用户 ${post.userId} · ${_postTime(post.createTime)}',
                    style: const TextStyle(
                      color: AdminColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _PostStatusTag(status: post.status),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          post.content,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(height: 1.55),
        ),
        if (post.books.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final book in post.books)
                Chip(
                  avatar: const Icon(Icons.menu_book_outlined, size: 16),
                  label: Text(book.title),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _PostMetric(
              icon: Icons.chat_bubble_outline,
              label: '${post.commentCount} 条评论',
            ),
            _PostMetric(
              icon: Icons.image_outlined,
              label: '${post.imageUrls.length} 张图片',
            ),
            if (onView != null)
              TextButton.icon(
                onPressed: onView,
                icon: const Icon(Icons.open_in_new, size: 17),
                label: const Text('查看'),
              ),
            OutlinedButton.icon(
              onPressed: changing ? null : onToggle,
              icon: changing
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      post.status == 1
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 17,
                    ),
              label: Text(adminCommunityPostActionLabel(post.status)),
            ),
          ],
        ),
      ],
    ),
  );
}

class _PostStatusTag extends StatelessWidget {
  const _PostStatusTag({required this.status});

  final int status;

  @override
  Widget build(BuildContext context) {
    final active = status == 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE7F3EC) : const Color(0xFFF8E9E7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        adminCommunityPostStatusLabel(status),
        style: TextStyle(
          color: active ? AdminColors.green : AdminColors.red,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PostMetric extends StatelessWidget {
  const _PostMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: AdminColors.muted),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(color: AdminColors.muted, fontSize: 12),
      ),
    ],
  );
}

class _CommunityPostsEmpty extends StatelessWidget {
  const _CommunityPostsEmpty();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 260,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 42, color: AdminColors.muted),
          SizedBox(height: 12),
          Text('没有符合筛选条件的帖子'),
        ],
      ),
    ),
  );
}

String _postTime(DateTime? value) => value == null
    ? '时间未知'
    : DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
