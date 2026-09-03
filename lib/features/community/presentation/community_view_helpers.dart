import '../../../data/models/book/book.dart';
import '../data/community_models.dart';

List<CommunityComment> arrangeCommunityComments(
  List<CommunityComment> comments,
) {
  final commentIds = comments.map((comment) => comment.id).toSet();
  final childrenByParent = <int, List<CommunityComment>>{};
  final roots = <CommunityComment>[];
  final orphanReplies = <CommunityComment>[];

  for (final comment in comments) {
    final parentId = comment.parentId;
    if (parentId == null) {
      roots.add(comment);
    } else if (!commentIds.contains(parentId)) {
      orphanReplies.add(comment);
    } else {
      childrenByParent.putIfAbsent(parentId, () => []).add(comment);
    }
  }

  final arranged = <CommunityComment>[];
  final visited = <int>{};

  void addWithReplies(CommunityComment comment) {
    if (!visited.add(comment.id)) return;
    arranged.add(comment);
    for (final reply in childrenByParent[comment.id] ?? const []) {
      addWithReplies(reply);
    }
  }

  for (final root in roots) {
    addWithReplies(root);
  }
  for (final orphanReply in orphanReplies) {
    addWithReplies(orphanReply);
  }
  for (final comment in comments) {
    addWithReplies(comment);
  }

  return arranged;
}

List<Book> filterCommunityBookOptions(
  List<Book> books,
  Set<int> selectedBookIds,
  String keyword,
) {
  final normalizedKeyword = keyword.trim().toLowerCase();
  final selected = <Book>[];
  final matches = <Book>[];

  for (final book in books) {
    if (selectedBookIds.contains(book.id)) {
      selected.add(book);
    } else if (normalizedKeyword.isEmpty ||
        book.title.toLowerCase().contains(normalizedKeyword)) {
      matches.add(book);
    }
  }

  return [...selected, ...matches];
}
