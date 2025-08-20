import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/filter_data_service.dart';
import '../services/asset_download_service.dart';

/// 이미지 경로 결과
class ImagePathResult {
  final String? localPath;
  final String? remotePath;
  final bool isLocalAvailable;

  const ImagePathResult({
    this.localPath,
    this.remotePath,
    required this.isLocalAvailable,
  });

  /// 사용할 경로 반환 (로컬 우선, 없으면 원격)
  String? get path => isLocalAvailable ? localPath : remotePath;

  @override
  String toString() {
    return 'ImagePathResult(local: $localPath, remote: $remotePath, localAvailable: $isLocalAvailable)';
  }
}

/// 이미지 경로 상태 관리
class ImagePathState {
  final Map<String, Map<String, ImagePathResult>> _cache = {};

  /// 캐시에서 이미지 경로 가져오기
  ImagePathResult? getCachedPath(String gameId, String assetKey) {
    return _cache[gameId]?[assetKey];
  }

  /// 캐시에 이미지 경로 저장
  void cachePath(String gameId, String assetKey, ImagePathResult result) {
    _cache[gameId] ??= {};
    _cache[gameId]![assetKey] = result;
  }

  /// 특정 게임의 캐시 무효화
  void invalidateGameCache(String gameId) {
    _cache.remove(gameId);
  }

  /// 전체 캐시 초기화
  void clearCache() {
    _cache.clear();
  }

  /// 캐시 상태 정보
  Map<String, int> getCacheStats() {
    final stats = <String, int>{};
    for (final entry in _cache.entries) {
      stats[entry.key] = entry.value.length;
    }
    return stats;
  }
}

/// 이미지 경로 관리 Provider
class ImagePathNotifier extends StateNotifier<ImagePathState> {
  ImagePathNotifier() : super(ImagePathState());

  /// 이미지 경로 계산 (캐시 적용)
  Future<ImagePathResult> getImagePath(String gameId, String assetKey) async {
    // 1. 캐시 확인
    final cached = state.getCachedPath(gameId, assetKey);
    if (cached != null) {
      return cached;
    }

    // 2. 새로운 경로 계산
    final result = await _calculateImagePath(gameId, assetKey);
    
    // 3. 캐시에 저장
    state.cachePath(gameId, assetKey, result);
    
    return result;
  }

  Future<ImagePathResult> _calculateImagePath(String gameId, String assetKey) async {
    try {
      // 매니페스트 로드
      final manifest = await FilterDataService.getManifestByFilterId(gameId);
      if (manifest == null) {
        return const ImagePathResult(isLocalAvailable: false);
      }

      // Asset 정보 찾기
      final asset = manifest.getAssetByKey(assetKey);
      if (asset == null) {
        return const ImagePathResult(isLocalAvailable: false);
      }

      // 로컬 경로 확인
      final localPath = await AssetDownloadService.getLocalAssetPath(gameId, asset.url);
      final isLocalAvailable = localPath != null && await File(localPath).exists();

      // 원격 경로
      final remotePath = manifest.getFullUrl(asset.url);

      return ImagePathResult(
        localPath: localPath,
        remotePath: remotePath,
        isLocalAvailable: isLocalAvailable,
      );
    } catch (e) {
      print('❌ 이미지 경로 계산 실패: $gameId:$assetKey - $e');
      return const ImagePathResult(isLocalAvailable: false);
    }
  }

  /// 특정 게임의 이미지 경로 캐시 무효화
  void invalidateGameCache(String gameId) {
    state.invalidateGameCache(gameId);
    // State 변경 알림
    state = ImagePathState()..clearCache();
    // 기존 캐시 복원 (해당 게임 제외)
    // Note: 실제로는 더 정교한 상태 업데이트 필요
  }

  /// 전체 캐시 초기화
  void clearCache() {
    state.clearCache();
    state = ImagePathState();
  }
}

/// ImagePath Provider 인스턴스
final imagePathProvider = StateNotifierProvider<ImagePathNotifier, ImagePathState>((ref) {
  return ImagePathNotifier();
});

/// 특정 게임+에셋키에 대한 이미지 경로 Provider
final imagePathResultProvider = FutureProvider.family<ImagePathResult, Map<String, String>>((ref, params) async {
  final gameId = params['gameId']!;
  final assetKey = params['assetKey']!;
  
  final notifier = ref.read(imagePathProvider.notifier);
  return await notifier.getImagePath(gameId, assetKey);
});

/// 편의 함수: 게임ID와 에셋키로 이미지 경로 가져오기
final getImagePathProvider = Provider<Future<ImagePathResult> Function(String, String)>((ref) {
  return (String gameId, String assetKey) async {
    final notifier = ref.read(imagePathProvider.notifier);
    return await notifier.getImagePath(gameId, assetKey);
  };
});