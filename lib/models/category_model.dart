class Category {
  final int id;
  final String name;
  final String? slug;
  final String? description;
  final String? media;
  final int? parentId;
  final String? type;
  final String? profit;
  final String? status;
  final List<Category>? children;

  Category({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.media,
    this.parentId,
    this.type,
    this.profit,
    this.status,
    this.children,
  });

  // Generate slug from name if not provided
  static String _generateSlug(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '') // Remove special characters
        .replaceAll(RegExp(r'\s+'), '-') // Replace spaces with hyphens
        .replaceAll(RegExp(r'-+'), '-') // Replace multiple hyphens with single
        .trim();
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    final categoryName = json['name'] ?? '';
    return Category(
      id: json['id'] ?? 0,
      name: categoryName,
      slug: json['slug'] ?? _generateSlug(categoryName),
      description: json['description'],
      media: json['media'],
      parentId: json['parent_id'],
      type: json['type'],
      profit: json['profit'],
      status: json['status'],
      children: (json['children'] as List?)
          ?.map((item) => Category.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'media': media,
      'parent_id': parentId,
      'type': type,
      'profit': profit,
      'status': status,
      'children': children?.map((item) => item.toJson()).toList(),
    };
  }

  bool get isParent => children != null && children!.isNotEmpty;
  bool get isChild => parentId != null;
}
