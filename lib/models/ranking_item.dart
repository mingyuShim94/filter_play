class RankingItem {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final String? imagePath; // assets 이미지 경로

  const RankingItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    this.imagePath, // optional 이미지 경로
  });

  RankingItem copyWith({
    String? id,
    String? name,
    String? emoji,
    String? description,
    String? imagePath,
  }) {
    return RankingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RankingItem &&
        other.id == id &&
        other.name == name &&
        other.emoji == emoji &&
        other.description == description &&
        other.imagePath == imagePath;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        emoji.hashCode ^
        description.hashCode ^
        imagePath.hashCode;
  }

  @override
  String toString() {
    return 'RankingItem(id: $id, name: $name, emoji: $emoji, description: $description, imagePath: $imagePath)';
  }

  // JSON 직렬화 (향후 확장용)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'description': description,
      'imagePath': imagePath,
    };
  }

  factory RankingItem.fromJson(Map<String, dynamic> json) {
    return RankingItem(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      description: json['description'] as String,
      imagePath: json['imagePath'] as String?,
    );
  }
}