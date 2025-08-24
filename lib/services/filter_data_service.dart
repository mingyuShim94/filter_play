import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/filter_category.dart';
import '../models/filter_item.dart';
import '../models/asset_manifest.dart';
import '../models/master_manifest.dart';
import 'manifest_cache_service.dart';
import 'asset_download_service.dart';

class FilterDataService {
  // 마스터 매니페스트 URL (Cloudflare R2)
  static const String _masterManifestUrl =
      'https://pub-a9df921416264d0199fb78dad1f43e02.r2.dev/master-manifest.json';

  // 로컬 매니페스트 경로는 AssetDownloadService에서 관리

  // 캐시된 마스터 매니페스트
  static MasterManifest? _cachedMasterManifest;

  // 업데이트 콜백
  static VoidCallback? _updateCallback;

  // Singleton Dio 인스턴스 (AssetDownloadService와 공유)
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 15),
  ));

  static bool _isInitialized = false;

  static void _initializeDio() {
    if (_isInitialized) return; // 중복 초기화 방지

    // LogInterceptor 추가 (디버깅용)
    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      requestHeader: true,
      responseHeader: false,
      logPrint: (object) => print('🌐 Filter HTTP: $object'),
    ));

    // 재시도 인터셉터 추가
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        print('❌ FilterDataService Dio 오류: ${error.type} - ${error.message}');
        print('   요청 URL: ${error.requestOptions.uri}');

        // 재시도 가능한 오류 타입 확인
        if (_shouldRetry(error) &&
            error.requestOptions.extra['retryCount'] == null) {
          error.requestOptions.extra['retryCount'] = 1;
          print('🔄 FilterDataService 재시도 시도 중...');

          try {
            await Future.delayed(const Duration(seconds: 1)); // 1초 대기
            final response = await _dio.fetch(error.requestOptions);
            return handler.resolve(response);
          } catch (retryError) {
            print('🔄 FilterDataService 재시도 실패: $retryError');
          }
        }

        handler.next(error);
      },
    ));

    _isInitialized = true;
    print('✅ FilterDataService Dio 초기화 완료 (singleton)');
  }

  static bool _shouldRetry(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.unknown;
  }

  static Future<List<FilterCategory>> getFilterCategories() async {
    final List<FilterCategory> categories = [];

    // 동적 랭킹 카테고리 생성
    final rankingItems = await _loadRankingFilters();
    if (rankingItems.isNotEmpty) {
      categories.add(
        FilterCategory(
          id: 'ranking',
          name: '랭킹 필터',
          icon: Icons.leaderboard,
          isEnabled: true,
          items: rankingItems,
        ),
      );
    }

    // 기타 카테고리들 (향후 동적으로 바뀔 예정)
    // categories.addAll(_getStaticCategories()); // 비활성화된 정적 카테고리 제거

    return categories;
  }

  /// 마스터 매니페스트를 로드 (로컬 파일 우선, 캐싱 적용)
  static Future<MasterManifest?> _loadMasterManifest() async {
    // 1단계: 메모리 캐시 확인
    if (_cachedMasterManifest != null) {
      print('⚡ 메모리 캐시된 마스터 매니페스트 사용 (즉시 로드)');
      return _cachedMasterManifest;
    }

    print('🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀');
    print('🔍 마스터 매니페스트 로드 시작 (로컬 파일 우선)');
    print('🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀');

    // 2단계: 로컬 파일 우선 확인
    try {
      final localManifest = await AssetDownloadService.getLocalMasterManifest();
      if (localManifest != null) {
        _cachedMasterManifest = localManifest;
        print(
            '📂✅ 로컬 마스터 매니페스트 로드 완료: ${localManifest.filters.length}개 필터 (네트워크 요청 없음)');

        // 백그라운드에서 업데이트 확인 (non-blocking)
        _checkForMasterManifestUpdate();

        return _cachedMasterManifest;
      }
      print('📂 로컬 마스터 매니페스트 없음, 원격에서 다운로드 시도');
    } catch (e) {
      print('⚠️ 로컬 마스터 매니페스트 로드 실패: $e');
    }

    // 3단계: 원격에서 다운로드
    try {
      print('🌐 원격 마스터 매니페스트 다운로드: $_masterManifestUrl');

      _initializeDio();

      final response = await _dio.get(
        _masterManifestUrl,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Cache-Control': 'no-cache',
          },
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      print(
          '📥 HTTP Response: ${response.statusCode} (${response.statusMessage})');

      if (response.statusCode == 200) {
        final jsonData = response.data as Map<String, dynamic>;
        _cachedMasterManifest = MasterManifest.fromJson(jsonData);

        // 로컬에 저장 (비동기 실행)
        AssetDownloadService.saveMasterManifest(_cachedMasterManifest!)
            .catchError((e) {
          print('⚠️ 마스터 매니페스트 로컬 저장 실패: $e');
        });

        print(
            '🌐✅ 원격 마스터 매니페스트 로드 성공: ${_cachedMasterManifest!.filters.length}개 필터');
        return _cachedMasterManifest;
      } else {
        print('❌ HTTP 요청 실패: ${response.statusCode} ${response.statusMessage}');
      }
    } catch (e) {
      print('❌ 원격 마스터 매니페스트 로드 실패: $e');
      if (e.toString().contains('TimeoutException')) {
        print('⏰ 네트워크 타임아웃 - 인터넷 연결을 확인해주세요');
      } else if (e.toString().contains('SocketException')) {
        print('🌐 네트워크 연결 실패 - DNS 또는 방화벽 문제일 수 있습니다');
      }
    }

    print('❌ 마스터 매니페스트 로드 실패: 로컬과 원격 모두 사용할 수 없음');
    return null;
  }

  /// 백그라운드에서 마스터 매니페스트 업데이트 확인 (non-blocking)
  static void _checkForMasterManifestUpdate() {
    // 백그라운드에서 비동기 실행 (UI 블로킹 방지)
    Future.delayed(Duration.zero, () async {
      try {
        print('🔄 백그라운드 마스터 매니페스트 업데이트 확인');

        // 원격에서 최신 버전 확인
        final response = await _dio.get(
          _masterManifestUrl,
          options: Options(
            headers: {
              'Accept': 'application/json',
              'Cache-Control': 'no-cache',
            },
            receiveTimeout: const Duration(seconds: 5), // 짧은 타임아웃
          ),
        );

        if (response.statusCode == 200) {
          final jsonData = response.data as Map<String, dynamic>;
          final remoteManifest = MasterManifest.fromJson(jsonData);

          // 로컬 버전과 비교
          if (_cachedMasterManifest != null &&
              remoteManifest.version != _cachedMasterManifest!.version) {
            print('🆕 새로운 마스터 매니페스트 버전 발견: ${remoteManifest.version}');

            // 메모리 캐시 업데이트
            _cachedMasterManifest = remoteManifest;

            // 로컬 파일 업데이트
            await AssetDownloadService.saveMasterManifest(remoteManifest);
            print('✅ 마스터 매니페스트 백그라운드 업데이트 완료');

            // 업데이트 콜백 호출 (UI 새로고침)
            if (_updateCallback != null) {
              _updateCallback!();
              print('📢 FilterProvider에 업데이트 알림 전송');
            }
          } else {
            print('✅ 마스터 매니페스트가 최신 버전입니다');
          }
        }
      } catch (e) {
        print('⚠️ 백그라운드 업데이트 확인 실패: $e (무시됨)');
        // 백그라운드 작업이므로 실패해도 앱 동작에 영향 없음
      }
    });
  }

  /// 마스터 매니페스트에서 랭킹 필터들을 동적으로 로드 (개별 매니페스트 다운로드 없이)
  static Future<List<FilterItem>> _loadRankingFilters() async {
    final List<FilterItem> filters = [];

    print('💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎');
    print('🔄🎯 랭킹 필터 로드 시작 (마스터 매니페스트 기반)');
    print('💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎');

    final masterManifest = await _loadMasterManifest();
    if (masterManifest == null) {
      print('❌ 마스터 매니페스트가 없어서 필터를 로드할 수 없습니다');
      return filters;
    }

    print('✅ 마스터 매니페스트 로드 완료: ${masterManifest.filters.length}개 필터 발견');

    // 랭킹 카테고리 필터들만 추출
    final rankingFilters = masterManifest.getFiltersByCategory('ranking');
    print('📊 랭킹 카테고리 필터: ${rankingFilters.length}개');

    for (final filterInfo in rankingFilters) {
      print(
          '🔍 필터 처리 중: ${filterInfo.gameId} (enabled: ${filterInfo.isEnabled})');

      if (!filterInfo.isEnabled) {
        print('⏩ 비활성화된 필터 건너뛰기: ${filterInfo.gameId}');
        continue;
      }

      // 마스터 매니페스트의 정보로 직접 FilterItem 생성 (네트워크 요청 없음)
      final filterItem = FilterItem(
        id: filterInfo.gameId,
        name: filterInfo.filterTitle,
        gameType: _parseGameType(filterInfo.filterType),
        isEnabled: filterInfo.isEnabled,
        manifestPath: filterInfo.manifestUrl,
        imageUrl: null, // 썸네일 제거됨
      );

      filters.add(filterItem);
      print('✅ 필터 추가 완료: ${filterItem.name} (네트워크 요청 없음)');
    }

    print(
        '🎯 랭킹 필터 로드 완료: ${filters.length}/${rankingFilters.length}개 성공 (즉시 로드)');
    return filters;
  }

  // gameType 문자열을 GameType enum으로 변환
  static GameType _parseGameType(String gameType) {
    switch (gameType.toLowerCase()) {
      case 'ranking':
        return GameType.ranking;
      case 'facetracking':
      case 'face_tracking':
        return GameType.faceTracking;
      case 'voicerecognition':
      case 'voice_recognition':
        return GameType.voiceRecognition;
      case 'quiz':
        return GameType.quiz;
      default:
        return GameType.ranking;
    }
  }

  // 정적 카테고리들은 제거됨 (모두 비활성화 상태였음)
  // 향후 서버에서 동적으로 로드될 예정

  static Future<FilterCategory?> getCategoryById(String id) async {
    final categories = await getFilterCategories();
    try {
      return categories.firstWhere((category) => category.id == id);
    } catch (e) {
      return null;
    }
  }

  static Future<FilterItem?> getFilterById(
      String categoryId, String filterId) async {
    final category = await getCategoryById(categoryId);
    if (category == null) return null;

    try {
      return category.items.firstWhere((item) => item.id == filterId);
    } catch (e) {
      return null;
    }
  }

  /// 필터 ID로 매니페스트 로드 (로컬 우선 + 캐싱 적용)
  static Future<AssetManifest?> getManifestByFilterId(String filterId) async {
    print('🔍 매니페스트 검색: $filterId');

    // 1순위: 로컬에 다운로드된 매니페스트 확인
    try {
      final localManifest =
          await AssetDownloadService.getLocalManifest(filterId);
      if (localManifest != null) {
        print('✅ 로컬 매니페스트 사용: $filterId (${localManifest.gameTitle})');
        print('   → 네트워크 요청 없음, 완전 로컬');
        return localManifest;
      }
      print('📂 로컬 매니페스트 없음, 원격 확인: $filterId');
    } catch (e) {
      print('⚠️ 로컬 매니페스트 로드 실패: $e');
    }

    // 2순위: 메모리 캐시 및 원격 로드
    final manifestCache = ManifestCacheService();

    return await manifestCache.getOrLoadManifest(filterId, () async {
      final masterManifest = await _loadMasterManifest();
      if (masterManifest == null) {
        print('❌ 마스터 매니페스트가 없어서 개별 매니페스트를 로드할 수 없습니다');
        return null;
      }

      final filterInfo = masterManifest.getFilterByGameId(filterId);
      if (filterInfo == null) {
        print('❌ 필터를 찾을 수 없음: $filterId');
        return null;
      }

      if (!filterInfo.isEnabled) {
        print('❌ 비활성화된 필터: $filterId');
        return null;
      }

      try {
        // 원격 매니페스트 로드 (재시도 적용)
        final manifestUrl =
            masterManifest.getFullManifestUrl(filterInfo.manifestUrl);
        print('📥 원격 매니페스트 다운로드: $manifestUrl');

        final response = await _dio.get(
          manifestUrl,
          options: Options(
            headers: {
              'Accept': 'application/json',
              'Cache-Control': 'no-cache',
            },
            receiveTimeout: const Duration(seconds: 15),
          ),
        );

        print(
            '📊 HTTP 응답: ${response.statusCode} (Content-Length: ${response.data.toString().length}B)');

        if (response.statusCode == 200) {
          try {
            print('📄 JSON 파싱 시작...');
            final jsonData = response.data as Map<String, dynamic>;
            print('✅ JSON 파싱 성공: ${jsonData.keys.toList()}');

            print('🔧 AssetManifest 객체 생성 시작...');
            final manifest = AssetManifest.fromJson(jsonData);
            print(
                '✅ 원격 매니페스트 로드 성공: ${manifest.gameId} (${manifest.assets.length}개 애셋)');
            return manifest;
          } catch (parseError) {
            print('❌ JSON 파싱 실패: $parseError');
            print(
                '📄 응답 본문 미리보기: ${response.data.toString().length > 500 ? '${response.data.toString().substring(0, 500)}...' : response.data.toString()}');
            return null;
          }
        } else {
          print('❌ HTTP 오류: ${response.statusCode} ${response.statusMessage}');
          print('📄 에러 응답: ${response.data}');
        }
      } catch (e) {
        print('❌ 원격 매니페스트 로드 실패: ${filterInfo.manifestUrl}');
        print('   에러: $e');

        if (e.toString().contains('TimeoutException')) {
          print('   → 네트워크 타임아웃 (15초 초과)');
        } else if (e.toString().contains('FormatException')) {
          print('   → JSON 파싱 오류');
        } else if (e.toString().contains('SocketException')) {
          print('   → 네트워크 연결 실패');
        }
      }
      return null;
    });
  }

  /// 마스터 매니페스트 캐시 초기화
  static void clearMasterManifestCache() {
    _cachedMasterManifest = null;
  }

  /// 마스터 매니페스트 강제 업데이트
  static Future<MasterManifest?> refreshMasterManifest() async {
    clearMasterManifestCache();
    return await _loadMasterManifest();
  }

  /// 마스터 매니페스트 접근용 public 메서드
  static Future<MasterManifest?> getMasterManifest() async {
    return await _loadMasterManifest();
  }

  /// 업데이트 콜백 설정
  static void setUpdateCallback(VoidCallback? callback) {
    _updateCallback = callback;
  }
}
