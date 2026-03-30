class Category {
  final int? id;
  final String name;
  final bool isEssential;
  final int? iconCode;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Category({
    this.id,
    required this.name,
    required this.isEssential,
    this.iconCode,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  // Convert a Category into a Map (to save to SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_essential': isEssential ? 1 : 0, // Convert bool to SQLite int
      'icon_code': iconCode,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Extract a Category object from a Map (reading from SQLite)
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      isEssential: map['is_essential'] == 1, // Convert SQLite int to bool
      iconCode: map['icon_code'],
      isDeleted: map['is_deleted'] == 1,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  // Create a copy with modified fields
  Category copyWith({
    int? id,
    String? name,
    bool? isEssential,
    int? iconCode,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      isEssential: isEssential ?? this.isEssential,
      iconCode: iconCode ?? this.iconCode,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}