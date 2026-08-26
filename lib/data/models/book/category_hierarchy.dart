import 'category.dart';

class CategoryHierarchy {
  const CategoryHierarchy(this.categories);

  final List<BookCategory> categories;

  List<BookCategory> get roots =>
      categories.where((category) => category.parentId == null).toList();

  List<BookCategory> childrenOf(int? parentId) => parentId == null
      ? const []
      : categories.where((category) => category.parentId == parentId).toList();

  BookCategory? findById(int? categoryId) {
    if (categoryId == null) return null;
    for (final category in categories) {
      if (category.id == categoryId) return category;
    }
    return null;
  }

  int? parentIdOf(int? selectedCategoryId) =>
      findById(selectedCategoryId)?.parentId;
}
