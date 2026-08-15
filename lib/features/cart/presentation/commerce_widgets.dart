import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';

abstract final class CommerceColors {
  static const canvas = Color(0xFFF7F6F2);
  static const ink = Color(0xFF171717);
  static const muted = Color(0xFF777570);
  static const placeholder = Color(0xFFA7A49D);
  static const line = Color(0xFFE5E3DE);
  static const sand = Color(0xFFEAE8E1);
  static const danger = Color(0xFF9D342E);
  static const success = Color(0xFF326448);
}

class CommerceHeader extends StatelessWidget {
  const CommerceHeader({required this.current, super.key});

  final String current;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CommerceColors.line)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final logo = InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => context.go('/books'),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_stories_outlined, size: 22),
                  SizedBox(width: 10),
                  Text(
                    '书间',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
          if (constraints.maxWidth < 560) {
            return Row(
              children: [
                logo,
                const Spacer(),
                Text(
                  _labelFor(current),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: '打开导航',
                  icon: const Icon(Icons.menu_rounded),
                  onSelected: (target) => context.go('/$target'),
                  itemBuilder: (context) => [
                    for (final item in _destinations)
                      PopupMenuItem(
                        value: item.$1,
                        child: Row(
                          children: [
                            Icon(item.$3, size: 19),
                            const SizedBox(width: 12),
                            Text(item.$2),
                            if (current == item.$1) ...[
                              const Spacer(),
                              const Icon(Icons.check_rounded, size: 18),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              logo,
              const Spacer(),
              for (final item in _destinations)
                _destination(context, item.$2, item.$3, item.$1),
            ],
          );
        },
      ),
    );
  }

  static const _destinations = <(String, String, IconData)>[
    ('books', '继续选书', Icons.menu_book_outlined),
    ('cart', '购物袋', Icons.shopping_bag_outlined),
    ('orders', '我的订单', Icons.receipt_long_outlined),
    ('reviews', '我的评价', Icons.rate_review_outlined),
    ('profile', '个人中心', Icons.person_outline_rounded),
  ];

  String _labelFor(String target) {
    for (final item in _destinations) {
      if (item.$1 == target) return item.$2;
    }
    return '导航';
  }

  Widget _destination(
    BuildContext context,
    String tooltip,
    IconData icon,
    String target,
  ) {
    final selected = current == target;
    return IconButton(
      tooltip: tooltip,
      onPressed: () => context.go('/$target'),
      color: selected ? Colors.white : CommerceColors.ink,
      style: IconButton.styleFrom(
        fixedSize: const Size(42, 42),
        backgroundColor: selected ? CommerceColors.ink : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

class CommerceLoadingState extends StatelessWidget {
  const CommerceLoadingState({this.message = '正在加载', super.key});

  final Object message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: CommerceColors.muted)),
          ],
        ),
      ),
    );
  }
}

class CommerceErrorState extends StatelessWidget {
  const CommerceErrorState({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: 14),
            Text(appErrorMessage(message, fallback: '暂时无法加载，请稍后重试'), textAlign: TextAlign.center),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新加载'),
            ),
          ],
        ),
      ),
    );
  }
}

class CommerceEmptyState extends StatelessWidget {
  const CommerceEmptyState({
    required this.icon,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 260),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: CommerceColors.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: CommerceColors.placeholder),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

class CommerceCountdown extends StatefulWidget {
  const CommerceCountdown({
    required this.expireTime,
    this.onExpired,
    this.prefix = '剩余支付时间',
    super.key,
  });

  final DateTime expireTime;
  final VoidCallback? onExpired;
  final String prefix;

  @override
  State<CommerceCountdown> createState() => _CommerceCountdownState();
}

class _CommerceCountdownState extends State<CommerceCountdown> {
  Timer? _timer;
  bool _reportedExpired = false;

  Duration get _remaining =>
      widget.expireTime.toLocal().difference(DateTime.now());

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant CommerceCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expireTime != widget.expireTime) {
      _reportedExpired = false;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_remaining <= Duration.zero && !_reportedExpired) {
        _reportedExpired = true;
        widget.onExpired?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining;
    final expired = remaining <= Duration.zero;
    final seconds = expired ? 0 : remaining.inSeconds;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    final value = hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    return Text(
      expired ? '支付时间已截止，正在刷新订单状态' : '${widget.prefix} $value',
      style: const TextStyle(
        color: CommerceColors.danger,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class CommerceTitle extends StatelessWidget {
  const CommerceTitle({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                color: CommerceColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                color: CommerceColors.ink,
                fontFamily: 'serif',
                fontSize: constraints.maxWidth < 560 ? 36 : 46,
                height: 1.08,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: const TextStyle(
                color: CommerceColors.muted,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        );
        if (trailing == null) return heading;
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 18), trailing!],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 24),
            trailing!,
          ],
        );
      },
    );
  }
}

class CommerceNotice extends StatelessWidget {
  const CommerceNotice({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: CommerceColors.danger.withValues(alpha: .07),
        border: Border.all(color: CommerceColors.danger.withValues(alpha: .25)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            size: 19,
            color: CommerceColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: CommerceColors.danger,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CommerceCover extends StatelessWidget {
  const CommerceCover({required this.url, this.width = 82, super.key});

  final String? url;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.35;
    if (url == null) return _placeholder(height);
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: CachedNetworkImage(
        imageUrl: url!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, _) => _placeholder(height),
        errorWidget: (_, _, _) => _placeholder(height),
      ),
    );
  }

  Widget _placeholder(double height) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color: CommerceColors.sand,
      child: const Icon(
        Icons.auto_stories_outlined,
        color: CommerceColors.placeholder,
      ),
    );
  }
}

String? commerceImageUrl(String baseUrl, String? path) {
  if (path == null || path.trim().isEmpty) return null;
  final uri = Uri.tryParse(path);
  if (uri != null && uri.hasScheme) return path;
  final root = baseUrl.replaceFirst(RegExp(r'/$'), '');
  final suffix = path.replaceFirst(RegExp(r'^/'), '');
  return '$root/$suffix';
}

String money(num value) => '¥${value.toStringAsFixed(2)}';
