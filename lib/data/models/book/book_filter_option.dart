class BookFilterOption {
  const BookFilterOption({required this.id, required this.name});

  factory BookFilterOption.fromJson(dynamic json) => BookFilterOption(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
      );

  final int id;
  final String name;
}
