class MasterManifest {
  final String version;
  final String lastUpdated;
  final String baseUrl;
  final List<FilterManifestInfo> filters;

  const MasterManifest({
    required this.version,
    required this.lastUpdated,
    required this.baseUrl,
    required this.filters,
  });

  factory MasterManifest.fromJson(Map<String, dynamic> json) {
    return MasterManifest(
      version: json['version'] as String,
      lastUpdated: json['lastUpdated'] as String,
      baseUrl: json['baseUrl'] as String,
      filters: (json['filters'] as List<dynamic>)
          .map((filter) => FilterManifestInfo.fromJson(filter as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'lastUpdated': lastUpdated,
      'baseUrl': baseUrl,
      'filters': filters.map((filter) => filter.toJson()).toList(),
    };
  }

  String getFullManifestUrl(String manifestUrl) {
    return '$baseUrl/$manifestUrl';
  }

  FilterManifestInfo? getFilterByGameId(String gameId) {
    try {
      return filters.firstWhere((filter) => filter.gameId == gameId);
    } catch (e) {
      return null;
    }
  }

  List<FilterManifestInfo> getEnabledFilters() {
    return filters.where((filter) => filter.isEnabled).toList();
  }

  List<FilterManifestInfo> getFiltersByCategory(String category) {
    return filters.where((filter) => filter.category == category).toList();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MasterManifest &&
        other.version == version &&
        other.lastUpdated == lastUpdated &&
        other.baseUrl == baseUrl &&
        other.filters.length == filters.length;
  }

  @override
  int get hashCode {
    return version.hashCode ^
        lastUpdated.hashCode ^
        baseUrl.hashCode ^
        filters.hashCode;
  }

  @override
  String toString() {
    return 'MasterManifest(version: $version, filters: ${filters.length})';
  }
}

class FilterManifestInfo {
  final String gameId;
  final String manifestUrl;
  final String category;
  final bool isEnabled;

  const FilterManifestInfo({
    required this.gameId,
    required this.manifestUrl,
    required this.category,
    required this.isEnabled,
  });

  factory FilterManifestInfo.fromJson(Map<String, dynamic> json) {
    return FilterManifestInfo(
      gameId: json['gameId'] as String,
      manifestUrl: json['manifestUrl'] as String,
      category: json['category'] as String,
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'manifestUrl': manifestUrl,
      'category': category,
      'isEnabled': isEnabled,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilterManifestInfo &&
        other.gameId == gameId &&
        other.manifestUrl == manifestUrl &&
        other.category == category &&
        other.isEnabled == isEnabled;
  }

  @override
  int get hashCode {
    return gameId.hashCode ^
        manifestUrl.hashCode ^
        category.hashCode ^
        isEnabled.hashCode;
  }

  @override
  String toString() {
    return 'FilterManifestInfo(gameId: $gameId, category: $category, enabled: $isEnabled)';
  }
}