class AssetManifest {
  final String gameId;
  final String version;
  final String gameTitle;
  final String description;
  final String gameType;
  final bool isEnabled;
  final String? thumbnailAsset;
  final String baseUrl;
  final List<AssetItem> assets;
  final List<Character> characters;
  final UIConfig? uiConfig;

  const AssetManifest({
    required this.gameId,
    required this.version,
    required this.gameTitle,
    required this.description,
    required this.gameType,
    required this.isEnabled,
    this.thumbnailAsset,
    required this.baseUrl,
    required this.assets,
    required this.characters,
    this.uiConfig,
  });

  factory AssetManifest.fromJson(Map<String, dynamic> json) {
    return AssetManifest(
      gameId: json['gameId'] as String,
      version: json['version'] as String,
      gameTitle: json['gameTitle'] as String,
      description: json['description'] as String,
      gameType: json['gameType'] as String? ?? 'ranking',
      isEnabled: json['isEnabled'] as bool? ?? true,
      thumbnailAsset: json['thumbnailAsset'] as String?,
      baseUrl: json['baseUrl'] as String,
      assets: (json['assets'] as List<dynamic>)
          .map((asset) => AssetItem.fromJson(asset as Map<String, dynamic>))
          .toList(),
      characters: (json['characters'] as List<dynamic>)
          .map((character) => Character.fromJson(character as Map<String, dynamic>))
          .toList(),
      uiConfig: json['ui'] != null 
          ? UIConfig.fromJson(json['ui'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'version': version,
      'gameTitle': gameTitle,
      'description': description,
      'gameType': gameType,
      'isEnabled': isEnabled,
      if (thumbnailAsset != null) 'thumbnailAsset': thumbnailAsset,
      'baseUrl': baseUrl,
      'assets': assets.map((asset) => asset.toJson()).toList(),
      'characters': characters.map((character) => character.toJson()).toList(),
      if (uiConfig != null) 'ui': uiConfig!.toJson(),
    };
  }

  String getFullUrl(String assetUrl) {
    return '$baseUrl/$assetUrl';
  }

  AssetItem? getAssetByKey(String key) {
    try {
      return assets.firstWhere((asset) => asset.key == key);
    } catch (e) {
      return null;
    }
  }

  Character? getCharacterById(String id) {
    try {
      return characters.firstWhere((character) => character.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AssetManifest &&
        other.gameId == gameId &&
        other.version == version &&
        other.gameTitle == gameTitle &&
        other.description == description &&
        other.gameType == gameType &&
        other.isEnabled == isEnabled &&
        other.thumbnailAsset == thumbnailAsset &&
        other.baseUrl == baseUrl &&
        other.assets.length == assets.length &&
        other.characters.length == characters.length &&
        other.uiConfig == uiConfig;
  }

  @override
  int get hashCode {
    return gameId.hashCode ^
        version.hashCode ^
        gameTitle.hashCode ^
        description.hashCode ^
        gameType.hashCode ^
        isEnabled.hashCode ^
        thumbnailAsset.hashCode ^
        baseUrl.hashCode ^
        assets.hashCode ^
        characters.hashCode ^
        uiConfig.hashCode;
  }

  @override
  String toString() {
    return 'AssetManifest(gameId: $gameId, version: $version, gameTitle: $gameTitle)';
  }
}

class AssetItem {
  final String type;
  final String key;
  final String name;
  final String url;

  const AssetItem({
    required this.type,
    required this.key,
    required this.name,
    required this.url,
  });

  factory AssetItem.fromJson(Map<String, dynamic> json) {
    return AssetItem(
      type: json['type'] as String,
      key: json['key'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'key': key,
      'name': name,
      'url': url,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AssetItem &&
        other.type == type &&
        other.key == key &&
        other.name == name &&
        other.url == url;
  }

  @override
  int get hashCode {
    return type.hashCode ^ key.hashCode ^ name.hashCode ^ url.hashCode;
  }

  @override
  String toString() {
    return 'AssetItem(key: $key, name: $name, type: $type)';
  }
}

class Character {
  final String id;
  final String assetKey;

  const Character({
    required this.id,
    required this.assetKey,
  });

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id'] as String,
      assetKey: json['assetKey'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assetKey': assetKey,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Character &&
        other.id == id &&
        other.assetKey == assetKey;
  }

  @override
  int get hashCode {
    return id.hashCode ^ assetKey.hashCode;
  }

  @override
  String toString() {
    return 'Character(id: $id, assetKey: $assetKey)';
  }
}

class UIConfig {
  final int slotCount;
  final int gridColumns;
  final double aspectRatio;

  const UIConfig({
    required this.slotCount,
    required this.gridColumns,
    required this.aspectRatio,
  });

  factory UIConfig.fromJson(Map<String, dynamic> json) {
    return UIConfig(
      slotCount: json['slotCount'] as int? ?? 10,
      gridColumns: json['gridColumns'] as int? ?? 2,
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? 0.65,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slotCount': slotCount,
      'gridColumns': gridColumns,
      'aspectRatio': aspectRatio,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UIConfig &&
        other.slotCount == slotCount &&
        other.gridColumns == gridColumns &&
        other.aspectRatio == aspectRatio;
  }

  @override
  int get hashCode {
    return slotCount.hashCode ^ gridColumns.hashCode ^ aspectRatio.hashCode;
  }

  @override
  String toString() {
    return 'UIConfig(slotCount: $slotCount, gridColumns: $gridColumns, aspectRatio: $aspectRatio)';
  }
}