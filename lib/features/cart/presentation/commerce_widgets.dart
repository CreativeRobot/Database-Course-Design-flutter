import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => context.go('/books'),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              child: Row(
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
          ),
          const Spacer(),
          _destination(context, '继续选书', Icons.menu_book_outlined, 'books'),
          _destination(context, '购物袋', Icons.shopping_bag_outlined, 'cart'),
          _destination(context, '我的订单', Icons.receipt_long_outlined, 'orders'),
          _destination(
            context,
            '个人中心',
            Icons.person_outline_rounded,
            'profile',
          ),
        ],
      ),
    );
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
