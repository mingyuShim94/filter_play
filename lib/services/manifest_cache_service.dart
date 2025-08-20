import 'dart:async';
import '../models/asset_manifest.dart';

/// 매니페스트 메모리 캐싱 서비스
/// 원격에서 로드한 매니페스트들을 메모리에 캐시하여 중복 네트워크 요청 방지
class ManifestCacheService {
  static final ManifestCacheService _instance = ManifestCacheService._internal();
  factory ManifestCacheService() => _instance;
  ManifestCacheService._internal();

  // 매니페스트 캐시 (gameId -> AssetManifest)
  final Map<String, AssetManifest> _manifestCache = {};
  
  // 진행 중인 로드 요청 (중복 요청 방지)
  final Map<String, Future<AssetManifest?>> _loadingRequests = {};
  
  // 캐시 만료 시간 (30분)
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 30);

  /// 매니페스트 가져오기 (캐시 우선)
  AssetManifest? getCachedManifest(String gameId) {
    // 캐시 만료 확인
    final timestamp = _cacheTimestamps[gameId];
    if (timestamp != null && DateTime.now().difference(timestamp) > _cacheExpiry) {
      _invalidateCache(gameId);
      return null;
    }
    
    return _manifestCache[gameId];
  }

  /// 매니페스트 캐시에 저장
  void cacheManifest(String gameId, AssetManifest manifest) {
    _manifestCache[gameId] = manifest;
    _cacheTimestamps[gameId] = DateTime.now();
    print('📦 매니페스트 캐시됨: $gameId (${manifest.gameTitle})');
  }

  /// 진행 중인 로드 요청 등록
  Future<AssetManifest?> getOrLoadManifest(
    String gameId, 
    Future<AssetManifest?> Function() loader
  ) async {
    // 1. 캐시된 매니페스트 확인
    final cached = getCachedManifest(gameId);
    if (cached != null) {
      print('✅ 캐시된 매니페스트 사용: $gameId');
      return cached;
    }

    // 2. 이미 로딩 중인 요청 확인 (중복 요청 방지)
    if (_loadingRequests.containsKey(gameId)) {
      print('⏳ 기존 로딩 요청 대기: $gameId');
      return await _loadingRequests[gameId];
    }

    // 3. 새로운 로딩 요청 시작
    print('🔄 새로운 매니페스트 로드 시작: $gameId');
    final loadingFuture = _executeLoad(gameId, loader);
    _loadingRequests[gameId] = loadingFuture;

    try {
      return await loadingFuture;
    } finally {
      // 로딩 완료 후 요청 제거
      _loadingRequests.remove(gameId);
    }
  }

  Future<AssetManifest?> _executeLoad(
    String gameId,
    Future<AssetManifest?> Function() loader
  ) async {
    try {
      final manifest = await loader();
      if (manifest != null) {
        cacheManifest(gameId, manifest);
      }
      return manifest;
    } catch (e) {
      print('❌ 매니페스트 로드 실패: $gameId - $e');
      return null;
    }
  }

  /// 특정 게임 캐시 무효화
  void _invalidateCache(String gameId) {
    _manifestCache.remove(gameId);
    _cacheTimestamps.remove(gameId);
    print('🗑️ 캐시 만료됨: $gameId');
  }

  /// 캐시 강제 무효화 (외부 호출용)
  void invalidateCache(String gameId) {
    _invalidateCache(gameId);
  }

  /// 전체 캐시 초기화
  void clearCache() {
    _manifestCache.clear();
    _cacheTimestamps.clear();
    _loadingRequests.clear();
    print('🧹 전체 매니페스트 캐시 초기화');
  }

  /// 캐시 통계 정보
  Map<String, dynamic> getCacheStats() {
    final now = DateTime.now();
    int expiredCount = 0;
    
    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _cacheExpiry) {
        expiredCount++;
      }
    }

    return {
      'totalCached': _manifestCache.length,
      'expiredCount': expiredCount,
      'loadingRequests': _loadingRequests.length,
      'cacheExpiry': '${_cacheExpiry.inMinutes}분',
    };
  }

  /// 현재 캐시된 게임 ID 목록
  List<String> getCachedGameIds() {
    return _manifestCache.keys.toList();
  }
}