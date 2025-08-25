import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/filter_item.dart';
import '../models/asset_manifest.dart';
import '../services/asset_download_service.dart';
import '../services/asset_cache_service.dart';
import '../services/filter_data_service.dart';
import '../services/manifest_cache_service.dart';

class AssetDownloadState {
  final Map<String, DownloadStatus> downloadStatuses;
  final Map<String, double> downloadProgresses;
  final Map<String, String?> errors;
  final bool isInitialized;

  const AssetDownloadState({
    this.downloadStatuses = const {},
    this.downloadProgresses = const {},
    this.errors = const {},
    this.isInitialized = false,
  });

  AssetDownloadState copyWith({
    Map<String, DownloadStatus>? downloadStatuses,
    Map<String, double>? downloadProgresses,
    Map<String, String?>? errors,
    bool? isInitialized,
  }) {
    return AssetDownloadState(
      downloadStatuses: downloadStatuses ?? this.downloadStatuses,
      downloadProgresses: downloadProgresses ?? this.downloadProgresses,
      errors: errors ?? this.errors,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  DownloadStatus getDownloadStatus(String filterId) {
    return downloadStatuses[filterId] ?? DownloadStatus.notDownloaded;
  }

  double getDownloadProgress(String filterId) {
    return downloadProgresses[filterId] ?? 0.0;
  }

  String? getError(String filterId) {
    return errors[filterId];
  }

  bool hasError(String filterId) {
    return errors[filterId] != null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AssetDownloadState &&
        other.downloadStatuses.length == downloadStatuses.length &&
        other.downloadProgresses.length == downloadProgresses.length &&
        other.errors.length == errors.length &&
        other.isInitialized == isInitialized;
  }

  @override
  int get hashCode {
    return downloadStatuses.hashCode ^
        downloadProgresses.hashCode ^
        errors.hashCode ^
        isInitialized.hashCode;
  }

  @override
  String toString() {
    return 'AssetDownloadState(statuses: ${downloadStatuses.length}, progresses: ${downloadProgresses.length}, errors: ${errors.length}, initialized: $isInitialized)';
  }
}

class AssetNotifier extends StateNotifier<AssetDownloadState> {
  AssetNotifier() : super(const AssetDownloadState()) {
    _initialize();
  }

  final Map<String, StreamSubscription> _downloadSubscriptions = {};
  Function(String)? _onDownloadComplete;

  Future<void> _initialize() async {
    try {
      await AssetCacheService.validateCache();

      final downloadedGames = await AssetCacheService.getDownloadedGames();
      final Map<String, DownloadStatus> statuses = {};
      final Map<String, double> progresses = {};

      for (final gameId in downloadedGames) {
        statuses[gameId] = await AssetCacheService.getDownloadStatus(gameId);
        progresses[gameId] =
            await AssetCacheService.getDownloadProgress(gameId);
      }

      state = state.copyWith(
        downloadStatuses: statuses,
        downloadProgresses: progresses,
        isInitialized: true,
      );
    } catch (e) {
      state = state.copyWith(isInitialized: true);
    }
  }

  Future<void> startDownload(String filterId, String manifestPath, {bool isUpdate = false}) async {
    print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
    print('🚀🎊 ${isUpdate ? "업데이트" : "다운로드"} 시작 요청: $filterId');
    print('📍📦 매니페스트 경로: $manifestPath');
    if (isUpdate) {
      print('🔄 업데이트 모드: 강화된 캐시 정리 및 파일 덮어쓰기');
    }
    print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');

    // 업데이트 모드인 경우 추가적인 캐시 정리
    if (isUpdate) {
      try {
        print('🧹 업데이트 모드: 매니페스트 캐시 정리 시작');
        final manifestCache = ManifestCacheService();
        manifestCache.invalidateCache(filterId);
        await AssetCacheService.clearFilterCache(filterId);
        print('✅ 업데이트 준비: 모든 캐시 정리 완료');
      } catch (e) {
        print('⚠️ 캐시 정리 중 오류 (계속 진행): $e');
      }
    }

    try {
      _updateDownloadStatus(filterId, DownloadStatus.downloading);
      _clearError(filterId);

      // 원격 전용: FilterDataService를 통해 매니페스트 로드
      print('📥 원격 매니페스트 로드 시도...');
      final manifest = await FilterDataService.getManifestByFilterId(filterId);

      if (manifest == null) {
        print('❌ 매니페스트를 찾을 수 없음: $filterId');
        throw Exception('매니페스트를 찾을 수 없습니다: $filterId');
      }

      print('✅ 매니페스트 로드 성공: ${manifest.gameTitle}');
      print('📊 다운로드할 파일 수: ${manifest.assets.length}개');

      late StreamSubscription subscription;
      subscription = _createDownloadStream(manifest).listen(
        (progress) {
          _updateDownloadProgress(filterId, progress.progress);
        },
        onDone: () {
          _updateDownloadStatus(filterId, DownloadStatus.downloaded);
          _updateDownloadProgress(filterId, 1.0);
          _downloadSubscriptions.remove(filterId);
          subscription.cancel();
          
          // 다운로드 완료 시 세션 캐시 제거 (이제 로컬 매니페스트 우선 사용)
          final manifestCache = ManifestCacheService();
          manifestCache.onFilterDownloaded(filterId);
          
          // 다운로드 완료 시 버전 정보 저장
          print('💾 다운로드 완료: 버전 정보 저장 시작...');
          _saveFilterVersion(filterId);
          
          // 다운로드 완료 콜백 호출
          print('📞 다운로드 완료 콜백 호출: $filterId');
          _onDownloadComplete?.call(filterId);
        },
        onError: (error) {
          _updateDownloadStatus(filterId, DownloadStatus.failed);
          _setError(filterId, error.toString());
          _downloadSubscriptions.remove(filterId);
          subscription.cancel();
        },
      );

      _downloadSubscriptions[filterId] = subscription;
    } catch (e) {
      _updateDownloadStatus(filterId, DownloadStatus.failed);
      _setError(filterId, e.toString());
    }
  }

  Stream<DownloadProgress> _createDownloadStream(AssetManifest manifest) {
    late StreamController<DownloadProgress> controller;

    controller = StreamController<DownloadProgress>(
      onListen: () async {
        try {
          await AssetDownloadService.downloadGameAssets(
            manifest,
            (progress) {
              if (!controller.isClosed) {
                controller.add(progress);
              }
              return Stream.value(progress);
            },
          );

          if (!controller.isClosed) {
            controller.close();
          }
        } catch (e) {
          if (!controller.isClosed) {
            controller.addError(e);
          }
        }
      },
      onCancel: () {
        if (!controller.isClosed) {
          controller.close();
        }
      },
    );

    return controller.stream;
  }

  void cancelDownload(String filterId) {
    final subscription = _downloadSubscriptions[filterId];
    if (subscription != null) {
      subscription.cancel();
      _downloadSubscriptions.remove(filterId);
      _updateDownloadStatus(filterId, DownloadStatus.notDownloaded);
      _updateDownloadProgress(filterId, 0.0);
      _clearError(filterId);
    }
  }

  Future<void> deleteAssets(String filterId) async {
    try {
      await AssetDownloadService.deleteGameAssets(filterId);
      await AssetCacheService.clearFilterCache(filterId);

      _updateDownloadStatus(filterId, DownloadStatus.notDownloaded);
      _updateDownloadProgress(filterId, 0.0);
      _clearError(filterId);
    } catch (e) {
      _setError(filterId, '삭제 실패: ${e.toString()}');
    }
  }

  Future<bool> isGameDownloaded(String filterId) async {
    return await AssetDownloadService.isGameDownloaded(filterId);
  }

  Future<String?> getLocalAssetPath(String gameId, String assetUrl) async {
    return await AssetDownloadService.getLocalAssetPath(gameId, assetUrl);
  }

  Future<double> getDownloadSize(String filterId) async {
    print('📏 다운로드 크기 조회 요청: $filterId');

    try {
      // 원격 전용: FilterDataService를 통해 매니페스트 로드
      final manifest = await FilterDataService.getManifestByFilterId(filterId);
      if (manifest == null) {
        print('❌ 매니페스트를 찾을 수 없음: $filterId');
        return -1;
      }

      return await AssetDownloadService.getDownloadSize(manifest);
    } catch (e) {
      print('❌ 다운로드 크기 계산 실패: $e');
      return -1;
    }
  }

  String formatFileSize(double bytes) {
    return AssetDownloadService.formatFileSize(bytes);
  }

  // Public method for external status updates
  void updateDownloadStatus(String filterId, DownloadStatus status) {
    _updateDownloadStatus(filterId, status);
  }

  void _updateDownloadStatus(String filterId, DownloadStatus status) {
    final newStatuses =
        Map<String, DownloadStatus>.from(state.downloadStatuses);
    newStatuses[filterId] = status;

    state = state.copyWith(downloadStatuses: newStatuses);

    AssetCacheService.setDownloadStatus(filterId, status);

    if (status == DownloadStatus.downloaded) {
      AssetCacheService.addDownloadedGame(filterId);
    }
  }

  void _updateDownloadProgress(String filterId, double progress) {
    final newProgresses = Map<String, double>.from(state.downloadProgresses);
    newProgresses[filterId] = progress;

    state = state.copyWith(downloadProgresses: newProgresses);
    AssetCacheService.setDownloadProgress(filterId, progress);
  }

  void _setError(String filterId, String error) {
    final newErrors = Map<String, String?>.from(state.errors);
    newErrors[filterId] = error;
    state = state.copyWith(errors: newErrors);
  }

  void _clearError(String filterId) {
    if (state.errors.containsKey(filterId)) {
      final newErrors = Map<String, String?>.from(state.errors);
      newErrors.remove(filterId);
      state = state.copyWith(errors: newErrors);
    }
  }

  Future<void> retryDownload(String filterId, String manifestPath) async {
    print('🔄 다운로드 재시도: $filterId');
    _clearError(filterId);
    await startDownload(filterId, manifestPath);
  }

  Future<Map<String, dynamic>> getCacheStats() async {
    return await AssetCacheService.getCacheStats();
  }

  Future<void> performCacheCleanup() async {
    await AssetCacheService.performCacheCleanup();
    await _initialize(); // 상태 새로고침
  }

  void setDownloadCompleteCallback(Function(String) callback) {
    _onDownloadComplete = callback;
  }

  /// 다운로드 완료 시 필터 버전 정보 저장
  Future<void> _saveFilterVersion(String filterId) async {
    try {
      print('🔍 로컬 매니페스트 조회 중: $filterId');
      // 로컬에 저장된 매니페스트에서 버전 정보 추출
      final manifest = await AssetDownloadService.getLocalManifest(filterId);
      if (manifest != null) {
        print('📋 매니페스트 발견: ${manifest.gameTitle} v${manifest.version}');
        await AssetCacheService.setFilterVersion(filterId, manifest.version);
        print('✅ 필터 버전 저장 완료: $filterId v${manifest.version}');
        
        // 저장된 버전 확인 (검증용)
        final savedVersion = await AssetCacheService.getFilterVersion(filterId);
        print('🔎 저장 검증: $filterId = v${savedVersion}');
        
        // 다운로드 완료로 버전 캐시 무효화 (새 버전이므로 다음 체크 시 다시 확인 필요)
        await AssetCacheService.clearVersionCheck(filterId);
        print('🧹 버전 체크 캐시 무효화: $filterId (새 버전으로 업데이트됨)');
      } else {
        print('⚠️ 필터 매니페스트를 찾을 수 없음: $filterId');
        print('💡 힌트: 매니페스트가 다운로드되지 않았거나 파일이 손상되었을 수 있습니다');
      }
    } catch (e) {
      print('❌ 필터 버전 저장 실패: $filterId - $e');
      print('🔧 디버깅: 로컬 파일 시스템 또는 권한 문제일 수 있습니다');
    }
  }

  @override
  void dispose() {
    for (final subscription in _downloadSubscriptions.values) {
      subscription.cancel();
    }
    _downloadSubscriptions.clear();
    super.dispose();
  }
}

final assetProvider =
    StateNotifierProvider<AssetNotifier, AssetDownloadState>((ref) {
  return AssetNotifier();
});

final downloadStatusProvider =
    Provider.family<DownloadStatus, String>((ref, filterId) {
  final assetState = ref.watch(assetProvider);
  return assetState.getDownloadStatus(filterId);
});

final downloadProgressProvider =
    Provider.family<double, String>((ref, filterId) {
  final assetState = ref.watch(assetProvider);
  return assetState.getDownloadProgress(filterId);
});

final downloadErrorProvider = Provider.family<String?, String>((ref, filterId) {
  final assetState = ref.watch(assetProvider);
  return assetState.getError(filterId);
});

final isGameDownloadedProvider =
    FutureProvider.family<bool, String>((ref, filterId) async {
  final notifier = ref.read(assetProvider.notifier);
  return await notifier.isGameDownloaded(filterId);
});

final downloadSizeProvider =
    FutureProvider.family<double, String>((ref, filterId) async {
  final notifier = ref.read(assetProvider.notifier);
  return await notifier.getDownloadSize(filterId);
});
