import 'package:shared_preferences/shared_preferences.dart';
import '../models/filter_item.dart';

class AssetCacheService {
  static const String _downloadStatusPrefix = 'download_status_';
  static const String _downloadProgressPrefix = 'download_progress_';
  static const String _manifestPathPrefix = 'manifest_path_';
  static const String _lastUpdatePrefix = 'last_update_';
  static const String _downloadedGamesKey = 'downloaded_games';

  static Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  static Future<void> setDownloadStatus(String filterId, DownloadStatus status) async {
    final prefs = await _getPrefs();
    await prefs.setString('$_downloadStatusPrefix$filterId', status.name);
  }

  static Future<DownloadStatus> getDownloadStatus(String filterId) async {
    final prefs = await _getPrefs();
    final statusString = prefs.getString('$_downloadStatusPrefix$filterId');
    
    if (statusString == null) {
      return DownloadStatus.notDownloaded;
    }

    switch (statusString) {
      case 'downloading':
        return DownloadStatus.downloading;
      case 'downloaded':
        return DownloadStatus.downloaded;
      case 'failed':
        return DownloadStatus.failed;
      default:
        return DownloadStatus.notDownloaded;
    }
  }

  static Future<void> setDownloadProgress(String filterId, double progress) async {
    final prefs = await _getPrefs();
    await prefs.setDouble('$_downloadProgressPrefix$filterId', progress);
  }

  static Future<double> getDownloadProgress(String filterId) async {
    final prefs = await _getPrefs();
    return prefs.getDouble('$_downloadProgressPrefix$filterId') ?? 0.0;
  }

  static Future<void> setManifestPath(String filterId, String? manifestPath) async {
    final prefs = await _getPrefs();
    if (manifestPath != null) {
      await prefs.setString('$_manifestPathPrefix$filterId', manifestPath);
    } else {
      await prefs.remove('$_manifestPathPrefix$filterId');
    }
  }

  static Future<String?> getManifestPath(String filterId) async {
    final prefs = await _getPrefs();
    return prefs.getString('$_manifestPathPrefix$filterId');
  }

  static Future<void> setLastUpdateTime(String filterId, DateTime dateTime) async {
    final prefs = await _getPrefs();
    await prefs.setString('$_lastUpdatePrefix$filterId', dateTime.toIso8601String());
  }

  static Future<DateTime?> getLastUpdateTime(String filterId) async {
    final prefs = await _getPrefs();
    final dateString = prefs.getString('$_lastUpdatePrefix$filterId');
    
    if (dateString != null) {
      try {
        return DateTime.parse(dateString);
      } catch (e) {
        return null;
      }
    }
    
    return null;
  }

  static Future<void> addDownloadedGame(String gameId) async {
    final prefs = await _getPrefs();
    final downloadedGames = await getDownloadedGames();
    
    if (!downloadedGames.contains(gameId)) {
      downloadedGames.add(gameId);
      await prefs.setStringList(_downloadedGamesKey, downloadedGames);
    }
  }

  static Future<void> removeDownloadedGame(String gameId) async {
    final prefs = await _getPrefs();
    final downloadedGames = await getDownloadedGames();
    
    if (downloadedGames.contains(gameId)) {
      downloadedGames.remove(gameId);
      await prefs.setStringList(_downloadedGamesKey, downloadedGames);
    }
  }

  static Future<List<String>> getDownloadedGames() async {
    final prefs = await _getPrefs();
    return prefs.getStringList(_downloadedGamesKey) ?? [];
  }

  static Future<bool> isGameDownloaded(String gameId) async {
    final downloadedGames = await getDownloadedGames();
    return downloadedGames.contains(gameId);
  }

  static Future<void> updateFilterItemCache(FilterItem filterItem) async {
    await setDownloadStatus(filterItem.id, filterItem.downloadStatus);
    await setDownloadProgress(filterItem.id, filterItem.downloadProgress);
    await setManifestPath(filterItem.id, filterItem.manifestPath);
    await setLastUpdateTime(filterItem.id, DateTime.now());
    
    if (filterItem.downloadStatus == DownloadStatus.downloaded) {
      await addDownloadedGame(filterItem.id);
    }
  }

  static Future<FilterItem> loadFilterItemFromCache(FilterItem baseItem) async {
    final downloadStatus = await getDownloadStatus(baseItem.id);
    final downloadProgress = await getDownloadProgress(baseItem.id);
    final manifestPath = await getManifestPath(baseItem.id);

    return baseItem.copyWith(
      downloadStatus: downloadStatus,
      downloadProgress: downloadProgress,
      manifestPath: manifestPath,
    );
  }

  static Future<void> clearFilterCache(String filterId) async {
    final prefs = await _getPrefs();
    
    await prefs.remove('$_downloadStatusPrefix$filterId');
    await prefs.remove('$_downloadProgressPrefix$filterId');
    await prefs.remove('$_manifestPathPrefix$filterId');
    await prefs.remove('$_lastUpdatePrefix$filterId');
    
    await removeDownloadedGame(filterId);
  }

  static Future<void> clearAllCache() async {
    final prefs = await _getPrefs();
    final keys = prefs.getKeys();
    
    for (final key in keys) {
      if (key.startsWith(_downloadStatusPrefix) ||
          key.startsWith(_downloadProgressPrefix) ||
          key.startsWith(_manifestPathPrefix) ||
          key.startsWith(_lastUpdatePrefix) ||
          key == _downloadedGamesKey) {
        await prefs.remove(key);
      }
    }
  }

  static Future<Map<String, dynamic>> getCacheStats() async {
    final downloadedGames = await getDownloadedGames();
    final prefs = await _getPrefs();
    final keys = prefs.getKeys();
    
    int downloadStatusCount = 0;
    int progressCount = 0;
    int manifestPathCount = 0;
    
    for (final key in keys) {
      if (key.startsWith(_downloadStatusPrefix)) {
        downloadStatusCount++;
      } else if (key.startsWith(_downloadProgressPrefix)) {
        progressCount++;
      } else if (key.startsWith(_manifestPathPrefix)) {
        manifestPathCount++;
      }
    }
    
    return {
      'downloadedGamesCount': downloadedGames.length,
      'downloadStatusCount': downloadStatusCount,
      'progressCount': progressCount,
      'manifestPathCount': manifestPathCount,
      'downloadedGames': downloadedGames,
    };
  }

  static Future<bool> needsCacheCleanup() async {
    final stats = await getCacheStats();
    
    // 캐시된 항목이 50개 이상이면 정리 필요
    final totalCachedItems = stats['downloadStatusCount'] as int;
    return totalCachedItems > 50;
  }

  static Future<void> performCacheCleanup() async {
    final prefs = await _getPrefs();
    final keys = prefs.getKeys();
    final now = DateTime.now();
    
    // 30일 이상 된 캐시 항목 제거
    for (final key in keys) {
      if (key.startsWith(_lastUpdatePrefix)) {
        final filterId = key.substring(_lastUpdatePrefix.length);
        final lastUpdate = await getLastUpdateTime(filterId);
        
        if (lastUpdate != null) {
          final daysDifference = now.difference(lastUpdate).inDays;
          
          if (daysDifference > 30) {
            await clearFilterCache(filterId);
          }
        }
      }
    }
  }

  static Future<int> getCacheSize() async {
    final stats = await getCacheStats();
    return (stats['downloadStatusCount'] as int) +
           (stats['progressCount'] as int) +
           (stats['manifestPathCount'] as int);
  }

  static Future<void> validateCache() async {
    final downloadedGames = await getDownloadedGames();
    final invalidGames = <String>[];
    
    for (final gameId in downloadedGames) {
      final status = await getDownloadStatus(gameId);
      
      if (status != DownloadStatus.downloaded) {
        invalidGames.add(gameId);
      }
    }
    
    // 잘못된 캐시 항목 제거
    for (final invalidGame in invalidGames) {
      await clearFilterCache(invalidGame);
    }
  }
}