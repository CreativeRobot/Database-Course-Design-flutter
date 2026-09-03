import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/media_url.dart';
import '../../../data/models/book/book.dart';
import '../../cart/presentation/commerce_widgets.dart';
import '../data/promotion_models.dart';
import '../../recommendations/data/recommendation_models.dart';
import '../../recommendations/presentation/recommendation_section.dart';
import 'homepage_controller.dart';

class HomepageSectionsView extends StatelessWidget {
  const HomepageSectionsView({
    required this.data,
    required this.baseUrl,
    required this.onBookTap,
    this.recommendation,
    this.onRecommendationLoadMore,
    this.recommendationLoadingMore = false,
    this.onRetry,
    super.key,
  });

  final HomepageState data;
  final String baseUrl;
  final ValueChanged<int> onBookTap;
  final RecommendationHome? recommendation;
  final VoidCallback? onRecommendationLoadMore;
  final bool recommendationLoadingMore;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[];
    if (data.promotions.discountedBooks.isNotEmpty ||
        data.promotions.bundles.isNotEmpty) {
      sections.add(
        _PromotionOffers(
          home: data.promotions,
          baseUrl: baseUrl,
          onBookTap: onBookTap,
        ),
      );
    }
    if (data.newReleases.isNotEmpty || data.bestSellers.isNotEmpty) {
      sections.add(
        _HotRankings(
          newReleases: data.newReleases,
          bestSellers: data.bestSellers,
          upcoming: data.upcoming,
          baseUrl: baseUrl,
          onBookTap: onBookTap,
        ),
      );
    }
    if (data.upcoming.isNotEmpty) {
      sections.add(
        _ReleaseCalendar(
          books: data.upcoming,
          baseUrl: baseUrl,
          onBookTap: onBookTap,
        ),
      );
    }
    if (recommendation != null) {
      sections.add(
        RecommendationBooks(
          home: recommendation!,
          baseUrl: baseUrl,
          onBookTap: onBookTap,
          onLoadMore: onRecommendationLoadMore,
          loadingMore: recommendationLoadingMore,
        ),
      );
    }
    if (data.errorMessage != null && sections.isNotEmpty) {
      sections.insert(0, CommerceNotice(message: data.errorMessage!));
    }
    if (sections.isEmpty && data.status == HomepageStatus.failure) {
      sections.add(
        CommerceErrorState(
          message: data.errorMessage ?? '首页内容暂时无法加载',
          onRetry: onRetry ?? () {},
        ),
      );
    } else if (sections.isEmpty && data.status == HomepageStatus.loading) {
      sections.add(const CommerceLoadingState(message: '正在准备首页内容'));
    } else if (sections.isEmpty && data.status == HomepageStatus.success) {
      sections.add(
        const CommerceEmptyState(
          icon: Icons.auto_stories_outlined,
          message: '暂时没有可展示的图书',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < sections.length; index++) ...[
          if (index > 0) const SizedBox(height: 54),
          sections[index],
        ],
      ],
    );
  }
}

class _PromotionOffers extends StatefulWidget {
  const _PromotionOffers({
    required this.home,
    required this.baseUrl,
    required this.onBookTap,
  });

  final PromotionHome home;
  final String baseUrl;
  final ValueChanged<int> onBookTap;

  @override
  State<_PromotionOffers> createState() => _PromotionOffersState();
}

class _PromotionOffersState extends State<_PromotionOffers> {
  late final PageController _pageController;
  Timer? _autoPlayTimer;
  var _currentPage = 0;

  int get _offerCount =>
      widget.home.discountedBooks.length + widget.home.bundles.length;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (_offerCount > 1) {
      _autoPlayTimer = Timer.periodic(
        const Duration(seconds: 6),
        (_) => _movePage(1),
      );
    }
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _movePage(int delta) {
    if (!_pageController.hasClients || _offerCount <= 1) return;
    final nextPage = HomepageSections.promotionPageIndex(
      _currentPage,
      _offerCount,
      delta,
    );
    _pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final offers = _offerCount;
    return _SectionShell(
      title: '折扣与活动',
      child: SizedBox(
        height: 316,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: offers,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: _promotionAt(index),
              ),
            ),
            if (offers > 1) ...[
              Positioned(
                left: 0,
                child: _PromotionCarouselButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: '上一个活动',
                  onPressed: () => _movePage(-1),
                ),
              ),
              Positioned(
                right: 0,
                child: _PromotionCarouselButton(
                  icon: Icons.chevron_right_rounded,
                  tooltip: '下一个活动',
                  onPressed: () => _movePage(1),
                ),
              ),
              Positioned(
                bottom: 0,
                child: _PromotionPageDots(
                  count: offers,
                  activeIndex: _currentPage,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _promotionAt(int index) {
    if (index < widget.home.discountedBooks.length) {
      final book = widget.home.discountedBooks[index];
      return _PromotionActivityCard(
        title: book.title,
        coverUrl: resolveMediaUrl(widget.baseUrl, book.coverUrl),
        badge: book.promotion?.discountLabel ?? '限时优惠',
        eyebrow: '图书限时折扣',
        description: book.promotion?.description ?? '限时直降，点击查看图书详情。',
        price: book.salePrice,
        originalPrice: book.baseSalePrice,
        badgeColor: const Color(0xFFB42318),
        badgeBackground: const Color(0xFFFFE4E1),
        onTap: () => widget.onBookTap(book.id),
      );
    }

    final bundle =
        widget.home.bundles[index - widget.home.discountedBooks.length];
    final featuredBook = bundle.items.isEmpty ? null : bundle.items.first;
    return _PromotionActivityCard(
      title: bundle.name,
      coverUrl: resolveMediaUrl(widget.baseUrl, featuredBook?.coverUrl),
      badge: '购买组合包省 ${money(bundle.savings)}',
      eyebrow: '精选优惠组合包',
      description: featuredBook == null
          ? '多本图书组合购买，享受额外优惠。'
          : '含《${featuredBook.title}》等 ${bundle.items.length} 本图书。',
      price: bundle.bundlePrice,
      originalPrice: bundle.regularAmount,
      badgeColor: const Color(0xFF9A3412),
      badgeBackground: const Color(0xFFFFEDD5),
      onTap: featuredBook == null
          ? null
          : () => widget.onBookTap(featuredBook.bookId),
    );
  }
}

class _PromotionActivityCard extends StatelessWidget {
  const _PromotionActivityCard({
    required this.title,
    required this.coverUrl,
    required this.badge,
    required this.eyebrow,
    required this.description,
    required this.badgeColor,
    required this.badgeBackground,
    required this.price,
    required this.originalPrice,
    this.onTap,
  });

  final String title;
  final String? coverUrl;
  final String badge;
  final String eyebrow;
  final String description;
  final Color badgeColor;
  final Color badgeBackground;
  final double price;
  final double originalPrice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF13283E), Color(0xFF1F4764)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x260B1F33),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final coverWidth = compact ? 122.0 : 280.0;
                final horizontalPadding = compact ? 18.0 : 30.0;
                return Stack(
                  children: [
                    Positioned(
                      top: -90,
                      right: -34,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x224DC4FF),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: coverWidth,
                      child: _PromotionActivityCover(url: coverUrl),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        28,
                        coverWidth + 12,
                        26,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            eyebrow,
                            style: const TextStyle(
                              color: Color(0xFF9AD7FF),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 20 : 26,
                              fontWeight: FontWeight.w900,
                              height: 1.18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFD5E6F4),
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Text(
                                money(price),
                                style: const TextStyle(
                                  color: Color(0xFFFFD37A),
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                money(originalPrice),
                                style: const TextStyle(
                                  color: Color(0xFFA9C2D4),
                                  fontSize: 13,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 18,
                      right: 18,
                      child: _PromotionBadge(
                        label: badge,
                        color: badgeColor,
                        backgroundColor: badgeBackground,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PromotionActivityCover extends StatelessWidget {
  const _PromotionActivityCover({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const _PromotionCoverPlaceholder();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: url!,
          fit: BoxFit.cover,
          placeholder: (_, _) => const _PromotionCoverPlaceholder(),
          errorWidget: (_, _, _) => const _PromotionCoverPlaceholder(),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1F4764), Color(0x001F4764)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ],
    );
  }
}

class _PromotionCarouselButton extends StatelessWidget {
  const _PromotionCarouselButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xE6FFFFFF),
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon, color: const Color(0xFF17324D)),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _PromotionPageDots extends StatelessWidget {
  const _PromotionPageDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: index == activeIndex ? 22 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: index == activeIndex
                ? const Color(0xFF17324D)
                : const Color(0xFFB8C5CF),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}

class _PromotionCoverPlaceholder extends StatelessWidget {
  const _PromotionCoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF3F0EA),
      child: Center(
        child: Icon(Icons.menu_book_outlined, color: CommerceColors.muted),
      ),
    );
  }
}

class _PromotionBadge extends StatelessWidget {
  const _PromotionBadge({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ReleaseCalendar extends StatefulWidget {
  const _ReleaseCalendar({
    required this.books,
    required this.baseUrl,
    required this.onBookTap,
  });
  final List<Book> books;
  final String baseUrl;
  final ValueChanged<int> onBookTap;

  @override
  State<_ReleaseCalendar> createState() => _ReleaseCalendarState();
}

class _ReleaseCalendarState extends State<_ReleaseCalendar> {
  static const _cardWidth = 290.0;
  static const _cardGap = 14.0;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (mounted) setState(() {});
  }

  void _scrollBy(double distance) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (position.pixels + distance)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canScrollBack =
        _scrollController.hasClients && _scrollController.offset > 0;
    final canScrollForward = _scrollController.hasClients
        ? _scrollController.offset < _scrollController.position.maxScrollExtent
        : widget.books.length > 1;
    return _SectionShell(
      title: '发售日历',
      child: SizedBox(
        height: 190,
        child: Row(
          children: [
            _CalendarArrow(
              tooltip: '上一组发售图书',
              icon: Icons.chevron_left,
              enabled: canScrollBack,
              onPressed: () => _scrollBy(-(_cardWidth + _cardGap)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                itemCount: widget.books.length,
                separatorBuilder: (_, _) => const SizedBox(width: _cardGap),
                itemBuilder: (context, index) {
                  final book = widget.books[index];
                  final release = book.preSaleReleaseTime!;
                  return InkWell(
                    onTap: () => widget.onBookTap(book.id),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: _cardWidth,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: CommerceColors.line),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 92,
                            child: CommerceCover(
                              url: commerceImageUrl(
                                widget.baseUrl,
                                book.coverUrl,
                              ),
                              width: 92,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('MM月dd日').format(release),
                                  style: const TextStyle(
                                    color: CommerceColors.success,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  book.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '预售 · ${DateFormat('HH:mm').format(release)} 发售',
                                  style: const TextStyle(
                                    color: CommerceColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            _CalendarArrow(
              tooltip: '下一组发售图书',
              icon: Icons.chevron_right,
              enabled: canScrollForward,
              onPressed: () => _scrollBy(_cardWidth + _cardGap),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarArrow extends StatelessWidget {
  const _CalendarArrow({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: CommerceColors.ink,
        disabledForegroundColor: CommerceColors.placeholder,
        side: const BorderSide(color: CommerceColors.line),
      ),
    );
  }
}

class _HotRankings extends StatelessWidget {
  const _HotRankings({
    required this.newReleases,
    required this.bestSellers,
    required this.upcoming,
    required this.baseUrl,
    required this.onBookTap,
  });
  final List<Book> newReleases;
  final List<Book> bestSellers;
  final List<Book> upcoming;
  final String baseUrl;
  final ValueChanged<int> onBookTap;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ('热门新品', newReleases),
      ('热销商品', bestSellers),
      ('热门即将推出', upcoming),
    ];
    return _SectionShell(
      title: '热门',
      child: DefaultTabController(
        length: tabs.length,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: CommerceColors.ink,
              unselectedLabelColor: CommerceColors.muted,
              indicatorColor: CommerceColors.ink,
              tabs: [for (final tab in tabs) Tab(text: tab.$1)],
            ),
            SizedBox(
              height: 360,
              child: TabBarView(
                children: [
                  for (final tab in tabs)
                    _RankingList(
                      books: tab.$2,
                      baseUrl: baseUrl,
                      onBookTap: onBookTap,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingList extends StatelessWidget {
  const _RankingList({
    required this.books,
    required this.baseUrl,
    required this.onBookTap,
  });
  final List<Book> books;
  final String baseUrl;
  final ValueChanged<int> onBookTap;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const Center(child: Text('暂时没有榜单数据'));
    return ListView.separated(
      padding: const EdgeInsets.only(top: 14),
      itemCount: books.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final book = books[index];
        return InkWell(
          onTap: () => onBookTap(book.id),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: CommerceColors.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '${index + 1}'.padLeft(2, '0'),
                    style: TextStyle(
                      color: index < 3
                          ? CommerceColors.ink
                          : CommerceColors.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: CommerceCover(
                    url: commerceImageUrl(baseUrl, book.coverUrl),
                    width: 42,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  money(book.salePrice),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}
