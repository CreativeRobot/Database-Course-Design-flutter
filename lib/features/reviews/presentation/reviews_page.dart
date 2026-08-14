import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../cart/presentation/commerce_widgets.dart';
import '../data/review_models.dart';
import 'reviews_controller.dart';

class ReviewsPage extends ConsumerStatefulWidget {
  const ReviewsPage({super.key});

  @override
  ConsumerState<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends ConsumerState<ReviewsPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(reviewsControllerProvider.notifier).loadMyReviews(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewsControllerProvider);
    final controller = ref.read(reviewsControllerProvider.notifier);
    return Scaffold(
      backgroundColor: CommerceColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            const CommerceHeader(current: 'reviews'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => controller.loadMyReviews(force: true),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 36, 20, 64),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CommerceTitle(
                            eyebrow: 'REVIEWS  ·  我的评价',
                            title: '读过，也留下回声',
                            subtitle: '集中查看和修改你提交过的图书评价。',
                            trailing: OutlinedButton.icon(
                              onPressed: () => context.go('/orders'),
                              icon: const Icon(
                                Icons.receipt_long_outlined,
                                size: 18,
                              ),
                              label: const Text('查看订单'),
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (state.errorMessage != null &&
                              state.reviews.isNotEmpty) ...[
                            CommerceNotice(message: state.errorMessage!),
                            const SizedBox(height: 18),
                          ],
                          if (state.status == ReviewsStatus.loading &&
                              state.reviews.isEmpty)
                            const CommerceLoadingState(message: '正在整理你的评价')
                          else if (state.status == ReviewsStatus.failure &&
                              state.reviews.isEmpty)
                            CommerceErrorState(
                              message: state.errorMessage ?? '评价暂时无法加载',
                              onRetry: () =>
                                  controller.loadMyReviews(force: true),
                            )
                          else if (state.reviews.isEmpty)
                            CommerceEmptyState(
                              icon: Icons.rate_review_outlined,
                              message: '还没有提交过评价',
                              action: FilledButton.icon(
                                onPressed: () => context.go('/orders'),
                                icon: const Icon(
                                  Icons.receipt_long_outlined,
                                  size: 18,
                                ),
                                label: const Text('查看已完成订单'),
                              ),
                            )
                          else ...[
                            for (
                              var index = 0;
                              index < state.visibleReviews.length;
                              index++
                            ) ...[
                              _ReviewCard(
                                review: state.visibleReviews[index],
                                busy:
                                    state.busyOrderItemId ==
                                    state.visibleReviews[index].orderItemId,
                                onEdit: () =>
                                    _editReview(state.visibleReviews[index]),
                              ),
                              if (index < state.visibleReviews.length - 1)
                                const SizedBox(height: 14),
                            ],
                            if (state.hasMore) ...[
                              const SizedBox(height: 22),
                              Center(
                                child: OutlinedButton.icon(
                                  onPressed: controller.loadMore,
                                  icon: const Icon(Icons.expand_more_rounded),
                                  label: Text(
                                    '加载更多（已显示 ${state.visibleReviews.length}/${state.reviews.length}）',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editReview(UserReview review) async {
    final draft = await showDialog<_ReviewDraft>(
      context: context,
      builder: (context) => _ReviewDialog(review: review),
    );
    if (draft == null || !mounted) return;
    final saved = await ref
        .read(reviewsControllerProvider.notifier)
        .saveReview(
          orderItemId: review.orderItemId,
          rating: draft.rating,
          content: draft.content,
          existing: review,
        );
    if (!mounted) return;
    final message = saved == null
        ? ref.read(reviewsControllerProvider).errorMessage ?? '评价修改失败，请稍后再试'
        : '评价已修改';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.busy,
    required this.onEdit,
  });

  final UserReview review;
  final bool busy;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: CommerceColors.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_stories_outlined, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.bookTitle.isEmpty
                          ? '图书 #${review.bookId}'
                          : review.bookTitle,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        for (var score = 1; score <= 5; score++)
                          Icon(
                            score <= review.rating
                                ? Icons.star
                                : Icons.star_border,
                            size: 18,
                            color: const Color(0xFFC58B26),
                          ),
                        const SizedBox(width: 10),
                        _ReviewStatus(status: review.status),
                      ],
                    ),
                  ],
                ),
              ),
              busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      tooltip: '修改评价',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            review.content.isEmpty ? '未填写文字评价' : review.content,
            style: TextStyle(
              color: review.content.isEmpty
                  ? CommerceColors.placeholder
                  : CommerceColors.ink,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _reviewTime(review),
            style: const TextStyle(
              color: CommerceColors.placeholder,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewStatus extends StatelessWidget {
  const _ReviewStatus({required this.status});

  final int status;

  @override
  Widget build(BuildContext context) {
    final visible = status == 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: (visible ? CommerceColors.success : CommerceColors.muted)
            .withValues(alpha: .09),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        visible ? '已展示' : '已屏蔽',
        style: TextStyle(
          color: visible ? CommerceColors.success : CommerceColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReviewDraft {
  const _ReviewDraft(this.rating, this.content);

  final int rating;
  final String content;
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.review});

  final UserReview review;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  late int _rating = widget.review.rating;
  late final TextEditingController _controller = TextEditingController(
    text: widget.review.content,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('修改评价'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('评分'),
            const SizedBox(height: 8),
            Wrap(
              children: [
                for (var score = 1; score <= 5; score++)
                  IconButton(
                    tooltip: '$score 分',
                    onPressed: () => setState(() => _rating = score),
                    color: score <= _rating
                        ? const Color(0xFFC58B26)
                        : CommerceColors.placeholder,
                    icon: const Icon(Icons.star),
                  ),
              ],
            ),
            TextField(
              controller: _controller,
              maxLength: 1000,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '分享这本书带给你的感受（可选）',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _ReviewDraft(_rating, _controller.text.trim()),
          ),
          child: const Text('保存评价'),
        ),
      ],
    );
  }
}

String _reviewTime(UserReview review) {
  final value = review.updateTime ?? review.createTime;
  if (value == null) return '时间未知';
  final prefix = review.updateTime != null ? '更新于' : '发布于';
  return '$prefix ${DateFormat('yyyy.MM.dd HH:mm').format(value.toLocal())}';
}
