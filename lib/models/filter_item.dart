enum GameType {
  ranking, // 랭킹 게임
  faceTracking, // 얼굴/신체 인식
  voiceRecognition, // 음성 인식
  quiz, // 퀴즈/상식
}

enum DownloadStatus {
  notDownloaded,
  downloading,
  downloaded,
  failed,
}

class FilterItem {
  final String id;
  final String name;
  final String? imageUrl;
  final GameType gameType;
  final bool isEnabled;
  final DownloadStatus downloadStatus;
  final double downloadProgress;
  final String? manifestPath;

  const FilterItem({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.gameType,
    required this.isEnabled,
    this.downloadStatus = DownloadStatus.notDownloaded,
    this.downloadProgress = 0.0,
    this.manifestPath,
  });

  FilterItem copyWith({
    String? id,
    String? name,
    String? imageUrl,
    GameType? gameType,
    bool? isEnabled,
    DownloadStatus? downloadStatus,
    double? downloadProgress,
    String? manifestPath,
  }) {
    return FilterItem(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      gameType: gameType ?? this.gameType,
      isEnabled: isEnabled ?? this.isEnabled,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      manifestPath: manifestPath ?? this.manifestPath,
    );
  }

  bool get isDownloaded => downloadStatus == DownloadStatus.downloaded;
  bool get isDownloading => downloadStatus == DownloadStatus.downloading;
  bool get downloadFailed => downloadStatus == DownloadStatus.failed;
  bool get needsDownload => downloadStatus == DownloadStatus.notDownloaded || downloadStatus == DownloadStatus.failed;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilterItem &&
        other.id == id &&
        other.name == name &&
        other.imageUrl == imageUrl &&
        other.gameType == gameType &&
        other.isEnabled == isEnabled &&
        other.downloadStatus == downloadStatus &&
        other.downloadProgress == downloadProgress &&
        other.manifestPath == manifestPath;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        imageUrl.hashCode ^
        gameType.hashCode ^
        isEnabled.hashCode ^
        downloadStatus.hashCode ^
        downloadProgress.hashCode ^
        manifestPath.hashCode;
  }

  @override
  String toString() {
    return 'FilterItem(id: $id, name: $name, gameType: $gameType, isEnabled: $isEnabled, downloadStatus: $downloadStatus)';
  }
}
