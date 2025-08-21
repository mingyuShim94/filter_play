import 'dart:async';
import '../models/asset_manifest.dart';

/// 매니페스트 메모리 캐싱 서비스 (세션 중에만)
/// 다운로드 전 UI 표시용 임시 캐시 - 다운로드된 필터는 로컬 매니페스트 우선 사용
class ManifestCacheService {
  static final ManifestCacheService _instance = ManifestCacheService._internal();
  factory ManifestCacheService() => _instance;
  ManifestCacheService._internal();

  // 매니페스트 캐시 (filterId -> AssetManifest) - 세션 중에만 유지
  final Map<String, AssetManifest> _manifestCache = {};
  
  // 진행 중인 로드 요청 (중복 요청 방지)
  final Map<String, Future<AssetManifest?>> _loadingRequests = {};

  /// 매니페스트 가져오기 (세션 캐시)
  AssetManifest? getCachedManifest(String filterId) {
    return _manifestCache[filterId];
  }

  /// 매니페스트 캐시에 저장 (세션 중에만)
  void cacheManifest(String filterId, AssetManifest manifest) {
    _manifestCache[filterId] = manifest;
    print('📦 매니페스트 세션 캐시됨: $filterId (${manifest.gameTitle}) - UI 표시용');
  }

  /// 진행 중인 로드 요청 등록
  Future<AssetManifest?> getOrLoadManifest(
    String filterId, 
    Future<AssetManifest?> Function() loader
  ) async {
    // 1. 캐시된 매니페스트 확인
    final cached = getCachedManifest(filterId);
    if (cached != null) {
      print('✅ 세션 캐시된 매니페스트 사용: $filterId');
      return cached;
    }

    // 2. 이미 로딩 중인 요청 확인 (중복 요청 방지)
    if (_loadingRequests.containsKey(filterId)) {
      print('⏳ 기존 로딩 요청 대기: $filterId');
      return await _loadingRequests[filterId];
    }

    // 3. 새로운 로딩 요청 시작
    print('🔄 새로운 매니페스트 로드 시작: $filterId');
    final loadingFuture = _executeLoad(filterId, loader);
    _loadingRequests[filterId] = loadingFuture;

    try {
      return await loadingFuture;
    } finally {
      // 로딩 완료 후 요청 제거
      _loadingRequests.remove(filterId);
    }
  }

  Future<AssetManifest?> _executeLoad(
    String filterId,
    Future<AssetManifest?> Function() loader
  ) async {
    try {
      final manifest = await loader();
      if (manifest != null) {
        cacheManifest(filterId, manifest);
      }
      return manifest;
    } catch (e) {
      print('❌ 매니페스트 로드 실패: $filterId - $e');
      return null;
    }
  }

  /// 특정 필터 캐시 무효화
  void invalidateCache(String filterId) {
    _manifestCache.remove(filterId);
    print('🗑️ 세션 캐시 제거됨: $filterId');
  }

  /// 전체 캐시 초기화
  void clearCache() {
    _manifestCache.clear();
    _loadingRequests.clear();
    print('🧹 전체 매니페스트 세션 캐시 초기화');
  }

  /// 캐시 통계 정보
  Map<String, dynamic> getCacheStats() {
    return {
      'totalCached': _manifestCache.length,
      'loadingRequests': _loadingRequests.length,
      'cacheType': '세션 캐시 (앱 재시작시 초기화)',
    };
  }

  /// 현재 캐시된 필터 ID 목록
  List<String> getCachedFilterIds() {
    return _manifestCache.keys.toList();
  }

  /// 다운로드 완료 시 해당 필터의 세션 캐시 제거 (로컬 매니페스트 우선 사용)
  void onFilterDownloaded(String filterId) {
    if (_manifestCache.containsKey(filterId)) {
      _manifestCache.remove(filterId);
      print('✅ 다운로드 완료로 세션 캐시 제거: $filterId (이제 로컬 매니페스트 사용)');
    }
  }
}