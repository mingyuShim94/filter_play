enum GameType {
  ranking, // 랭킹 게임
  faceTracking, // 얼굴/신체 인식
  voiceRecognition, // 음성 인식
  quiz, // 퀴즈/상식
}

class FilterItem {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final GameType gameType;
  final bool isEnabled;

  const FilterItem({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.gameType,
    required this.isEnabled,
  });

  FilterItem copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    GameType? gameType,
    bool? isEnabled,
  }) {
    return FilterItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      gameType: gameType ?? this.gameType,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilterItem &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.imageUrl == imageUrl &&
        other.gameType == gameType &&
        other.isEnabled == isEnabled;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        description.hashCode ^
        imageUrl.hashCode ^
        gameType.hashCode ^
        isEnabled.hashCode;
  }

  @override
  String toString() {
    return 'FilterItem(id: $id, name: $name, gameType: $gameType, isEnabled: $isEnabled)';
  }
}
