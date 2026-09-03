import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/community_models.dart';

abstract final class CommunityColors {
  static const canvas = Color(0xFFF7F6F2);
  static const ink = Color(0xFF1A1917);
  static const muted = Color(0xFF77736C);
  static const line = Color(0xFFE6E2DA);
  static const accent = Color(0xFFB7862F);
  static const softAccent = Color(0xFFF6ECD8);
}

String communityMediaUrl(String baseUrl, String? path) {
  final value = path?.trim() ?? '';
  if (value.isEmpty) return '';
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) return value;
  return '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/${value.replaceFirst(RegExp(r'^/+'), '')}';
}

String communityTime(DateTime? value) {
  if (value == null) return '';
  return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
}

class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({
    required this.name,
    required this.baseUrl,
    this.avatar,
    this.radius = 20,
    super.key,
  });

  final String name;
  final String baseUrl;
  final String? avatar;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final imageUrl = communityMediaUrl(baseUrl, avatar);
    return CircleAvatar(
      radius: radius,
      backgroundColor: CommunityColors.softAccent,
      foregroundImage: imageUrl.isEmpty
          ? null
          : CachedNetworkImageProvider(imageUrl),
      child: imageUrl.isEmpty
          ? Text(
              name.trim().isEmpty ? '读' : name.trim().characters.first,
              style: const TextStyle(
                color: CommunityColors.ink,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}

class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    required this.post,
    required this.baseUrl,
    required this.onTap,
    super.key,
  });

  final CommunityPost post;
  final String baseUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: CommunityColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CommunityAvatar(
                    name: post.authorName,
                    avatar: post.authorAvatar,
                    baseUrl: baseUrl,
                  ),
                  const SizedBox(width: 11),
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
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: CommunityColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color: CommunityColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                post.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  height: 1.55,
                  color: CommunityColors.muted,
                ),
              ),
              if (post.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 16),
                CommunityImageGrid(imageUrls: post.imageUrls, baseUrl: baseUrl),
              ],
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: CommunityBookChips(books: post.books)),
                  const SizedBox(width: 12),
                  const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  const SizedBox(width: 5),
                  Text('${post.commentCount}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CommunityImageGrid extends StatelessWidget {
  const CommunityImageGrid({
    required this.imageUrls,
    required this.baseUrl,
    super.key,
  });

  final List<String> imageUrls;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final shown = imageUrls.take(3).toList(growable: false);
    return SizedBox(
      height: 150,
      child: Row(
        children: [
          for (var index = 0; index < shown.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: communityMediaUrl(baseUrl, shown[index]),
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          const ColoredBox(color: CommunityColors.softAccent),
                      errorWidget: (_, _, _) => const ColoredBox(
                        color: CommunityColors.softAccent,
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                  if (index == 2 && imageUrls.length > shown.length)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '+${imageUrls.length - shown.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CommunityBookChips extends StatelessWidget {
  const CommunityBookChips({required this.books, super.key});

  final List<CommunityBookRef> books;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final book in books)
          Chip(
            avatar: const Icon(Icons.menu_book_outlined, size: 16),
            label: Text(book.title, overflow: TextOverflow.ellipsis),
            visualDensity: VisualDensity.compact,
            backgroundColor: CommunityColors.softAccent,
            side: BorderSide.none,
          ),
      ],
    );
  }
}
