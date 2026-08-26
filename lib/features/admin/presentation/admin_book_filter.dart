enum AdminBookFilterType { author, publisher, category }

class AdminBookFilter {
  const AdminBookFilter._({
    required this.type,
    required this.id,
    required this.name,
  });

  const AdminBookFilter.author({required int id, required String name})
    : this._(type: AdminBookFilterType.author, id: id, name: name);

  const AdminBookFilter.publisher({required int id, required String name})
    : this._(type: AdminBookFilterType.publisher, id: id, name: name);

  const AdminBookFilter.category({required int id, required String name})
    : this._(type: AdminBookFilterType.category, id: id, name: name);

  final AdminBookFilterType type;
  final int id;
  final String name;

  int? get authorId => type == AdminBookFilterType.author ? id : null;
  int? get publisherId => type == AdminBookFilterType.publisher ? id : null;
  int? get categoryId => type == AdminBookFilterType.category ? id : null;

  String get managementLabel => switch (type) {
    AdminBookFilterType.author => '正在管理：$name 的图书',
    AdminBookFilterType.publisher => '正在管理：$name 的图书',
    AdminBookFilterType.category => '正在管理：$name 分类图书',
  };
}
