import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/filter_category.dart';
import '../models/filter_item.dart';
import '../models/asset_manifest.dart';
import '../models/master_manifest.dart';
import 'manifest_cache_service.dart';
import 'network_retry_service.dart';

class FilterDataService {
  // 마스터 매니페스트 URL (Cloudflare R2)
  static const String _masterManifestUrl = 'https://pub-a9df921416264d0199fb78dad1f43e02.r2.dev/master-manifest.json';
  
  // 로컬 매니페스트 경로 (개발용/오프라인 지원)
  static const List<String> _fallbackManifestPaths = [
    'assets/images/ranking/manifest.json',
    // 향후 추가될 매니페스트들
  ];

  // 캐시된 마스터 매니페스트
  static MasterManifest? _cachedMasterManifest;

  static Future<List<FilterCategory>> getFilterCategories() async {
    final List<FilterCategory> categories = [];
    
    // 동적 랭킹 카테고리 생성
    final rankingItems = await _loadRankingFilters();
    if (rankingItems.isNotEmpty) {
      categories.add(
        FilterCategory(
          id: 'ranking',
          name: '랭킹 필터',
          description: '다양한 주제로 순위를 매기는 게임',
          icon: Icons.leaderboard,
          isEnabled: true,
          items: rankingItems,
        ),
      );
    }
    
    // 기타 카테고리들 (향후 동적으로 바뀔 예정)
    categories.addAll(_getStaticCategories());
    
    return categories;
  }

  /// 마스터 매니페스트를 로드하고 캐싱
  static Future<MasterManifest?> _loadMasterManifest() async {
    if (_cachedMasterManifest != null) {
      print('🔄 캐시된 마스터 매니페스트 사용');
      return _cachedMasterManifest;
    }

    print('🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀');
    print('🌐🔥 원격 마스터 매니페스트 로드 시도: $_masterManifestUrl');
    print('🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀');
    
    try {
      // 원격 마스터 매니페스트 다운로드 시도 (재시도 적용)
      final retryResult = await NetworkRetryService.retryHttpGet(
        _masterManifestUrl,
        headers: {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        },
        timeout: const Duration(seconds: 10),
        config: const RetryConfig(
          maxRetries: 2,
          baseDelay: Duration(seconds: 1),
        ),
      );
      
      if (!retryResult.isSuccess || retryResult.data == null) {
        throw retryResult.error ?? Exception('마스터 매니페스트 다운로드 실패');
      }
      
      final response = retryResult.data!;
      print('📥 HTTP Response: ${response.statusCode} (${response.reasonPhrase})');
      print('📊 Response size: ${response.contentLength ?? response.body.length} bytes');
      
      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body) as Map<String, dynamic>;
          _cachedMasterManifest = MasterManifest.fromJson(jsonData);
          print('🎉🎉🎉 ✅ 원격 마스터 매니페스트 로드 성공: ${_cachedMasterManifest!.filters.length}개 필터 🎉🎉🎉');
          return _cachedMasterManifest;
        } catch (parseError) {
          print('❌ JSON 파싱 실패: $parseError');
          print('📄 Response body preview: ${response.body.length > 200 ? response.body.substring(0, 200) + '...' : response.body}');
        }
      } else {
        print('❌ HTTP 요청 실패: ${response.statusCode} ${response.reasonPhrase}');
        print('📄 Error body: ${response.body}');
      }
    } catch (e) {
      print('❌ 원격 마스터 매니페스트 로드 실패: $e');
      if (e.toString().contains('TimeoutException')) {
        print('⏰ 네트워크 타임아웃 - 인터넷 연결을 확인해주세요');
      } else if (e.toString().contains('SocketException')) {
        print('🌐 네트워크 연결 실패 - DNS 또는 방화벽 문제일 수 있습니다');
      } else if (e.toString().contains('HandshakeException')) {
        print('🔒 SSL 인증서 문제');
      }
    }

    print('🔄 폴백 모드로 전환');
    // 폴백: 로컬 매니페스트 사용
    return await _loadFallbackMasterManifest();
  }

  /// 원격 전용 환경을 위한 폴백 처리 (실제로는 null 반환)
  static Future<MasterManifest?> _loadFallbackMasterManifest() async {
    print('❌ 폴백 모드: 원격 전용 환경에서는 로컬 매니페스트가 없습니다');
    print('💡 해결방안:');
    print('   1. 인터넷 연결 상태를 확인하세요');
    print('   2. Cloudflare R2 URL이 올바른지 확인하세요: $_masterManifestUrl');
    print('   3. 방화벽이나 프록시 설정을 확인하세요');
    
    // 원격 전용 환경에서는 fallback 없음
    return null;
  }

  /// 마스터 매니페스트에서 랭킹 필터들을 동적으로 로드
  static Future<List<FilterItem>> _loadRankingFilters() async {
    final List<FilterItem> filters = [];
    
    print('💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎💎');
    print('🔄🎯 랭킹 필터 로드 시작');
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
      print('🔍 필터 처리 중: ${filterInfo.gameId} (enabled: ${filterInfo.isEnabled})');
      
      if (!filterInfo.isEnabled) {
        print('⏩ 비활성화된 필터 건너뛰기: ${filterInfo.gameId}');
        continue;
      }
      
      try {
        AssetManifest manifest;
        final manifestUrl = masterManifest.getFullManifestUrl(filterInfo.manifestUrl);
        
        print('📥 개별 매니페스트 다운로드 시도: $manifestUrl');
        
        // 원격 매니페스트 로드 (재시도 적용)
        final retryResult = await NetworkRetryService.retryHttpGet(
          manifestUrl,
          headers: {
            'Accept': 'application/json',
            'Cache-Control': 'no-cache',
          },
          timeout: const Duration(seconds: 15),
          config: const RetryConfig(
            maxRetries: 2,
            baseDelay: Duration(seconds: 1),
          ),
        );
        
        if (!retryResult.isSuccess || retryResult.data == null) {
          print('❌ 매니페스트 다운로드 실패: ${retryResult.error}');
          continue;
        }
        
        final response = retryResult.data!;
        print('📋 매니페스트 응답: ${response.statusCode} (${response.contentLength ?? response.body.length}B)');
        
        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body) as Map<String, dynamic>;
          manifest = AssetManifest.fromJson(jsonData);
          print('✅ 매니페스트 파싱 성공: ${manifest.gameTitle}');
        } else {
          print('❌ 매니페스트 다운로드 실패: HTTP ${response.statusCode}');
          print('📄 에러 응답: ${response.body}');
          continue;
        }
        
        // 매니페스트에서 FilterItem 생성
        final filterItem = FilterItem(
          id: manifest.gameId,
          name: manifest.gameTitle,
          description: manifest.description,
          gameType: _parseGameType(manifest.gameType),
          isEnabled: manifest.isEnabled,
          manifestPath: filterInfo.manifestUrl,
          imageUrl: manifest.thumbnailAsset != null 
              ? manifest.getFullUrl(manifest.getAssetByKey(manifest.thumbnailAsset!)?.url ?? '')
              : null,
        );
        
        filters.add(filterItem);
        print('✅ 필터 추가 완료: ${filterItem.name} (썸네일: ${filterItem.imageUrl != null ? '있음' : '없음'})');
        
      } catch (e) {
        print('❌ 필터 처리 실패: ${filterInfo.gameId}');
        print('   URL: ${masterManifest.getFullManifestUrl(filterInfo.manifestUrl)}');
        print('   에러: $e');
        
        if (e.toString().contains('TimeoutException')) {
          print('   → 네트워크 타임아웃');
        } else if (e.toString().contains('FormatException')) {
          print('   → JSON 형식 오류');
        } else if (e.toString().contains('SocketException')) {
          print('   → 네트워크 연결 실패');
        }
      }
    }
    
    print('🎯 랭킹 필터 로드 완료: ${filters.length}/${rankingFilters.length}개 성공');
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

  // 정적 카테고리들 (향후 동적으로 변환 예정)
  static List<FilterCategory> _getStaticCategories() {
    return [
      FilterCategory(
        id: 'face_tracking',
        name: '얼굴/신체 인식',
        description: '얼굴과 몸의 움직임으로 즐기는 게임',
        icon: Icons.face,
        isEnabled: false,
        items: _getFaceTrackingFilters(),
      ),
      FilterCategory(
        id: 'voice_recognition',
        name: '음성 인식',
        description: '목소리와 소리로 플레이하는 게임',
        icon: Icons.mic,
        isEnabled: false,
        items: _getVoiceRecognitionFilters(),
      ),
      FilterCategory(
        id: 'quiz',
        name: '퀴즈/상식',
        description: '지식과 상식을 테스트하는 게임',
        icon: Icons.quiz,
        isEnabled: false,
        items: _getQuizFilters(),
      ),
    ];
  }
  
  static List<FilterItem> _getFaceTrackingFilters() {
    return [
      const FilterItem(
        id: 'expression_copy',
        name: '표정 따라하기',
        description: '화면의 표정을 똑같이 따라해보세요',
        gameType: GameType.faceTracking,
        isEnabled: false,
      ),
      const FilterItem(
        id: 'eye_blink_game',
        name: '눈깜빡임 게임',
        description: '눈을 깜빡여서 캐릭터를 조종하세요',
        gameType: GameType.faceTracking,
        isEnabled: false,
      ),
      const FilterItem(
        id: 'face_puzzle',
        name: '얼굴 퍼즐',
        description: '얼굴을 움직여서 퍼즐을 맞춰보세요',
        gameType: GameType.faceTracking,
        isEnabled: false,
      ),
    ];
  }

  static List<FilterItem> _getVoiceRecognitionFilters() {
    return [
      const FilterItem(
        id: 'perfect_pitch',
        name: '절대음감 챌린지',
        description: '정확한 음정으로 노래해보세요',
        gameType: GameType.voiceRecognition,
        isEnabled: false,
      ),
      const FilterItem(
        id: 'pronunciation_game',
        name: '발음 게임',
        description: '정확한 발음으로 단어를 말해보세요',
        gameType: GameType.voiceRecognition,
        isEnabled: false,
      ),
      const FilterItem(
        id: 'volume_control',
        name: '소리 크기 조절',
        description: '목소리 크기로 캐릭터를 조종하세요',
        gameType: GameType.voiceRecognition,
        isEnabled: false,
      ),
    ];
  }

  static List<FilterItem> _getQuizFilters() {
    return [
      const FilterItem(
        id: 'ox_quiz',
        name: 'O/X 퀴즈',
        description: '참과 거짓을 구별해보세요',
        gameType: GameType.quiz,
        isEnabled: false,
      ),
      const FilterItem(
        id: 'multiple_choice',
        name: '객관식 퀴즈',
        description: '정답을 골라보세요',
        gameType: GameType.quiz,
        isEnabled: false,
      ),
      const FilterItem(
        id: 'capital_quiz',
        name: '수도 맞추기',
        description: '나라의 수도를 맞춰보세요',
        gameType: GameType.quiz,
        isEnabled: false,
      ),
    ];
  }

  static Future<FilterCategory?> getCategoryById(String id) async {
    final categories = await getFilterCategories();
    try {
      return categories.firstWhere((category) => category.id == id);
    } catch (e) {
      return null;
    }
  }

  static Future<FilterItem?> getFilterById(String categoryId, String filterId) async {
    final category = await getCategoryById(categoryId);
    if (category == null) return null;

    try {
      return category.items.firstWhere((item) => item.id == filterId);
    } catch (e) {
      return null;
    }
  }
  
  /// 필터 ID로 매니페스트 로드 (캐싱 적용)
  static Future<AssetManifest?> getManifestByFilterId(String filterId) async {
    print('🔍 매니페스트 검색: $filterId');
    
    // 캐싱 서비스 사용
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
        final manifestUrl = masterManifest.getFullManifestUrl(filterInfo.manifestUrl);
        print('📥 매니페스트 다운로드: $manifestUrl');
        
        final retryResult = await NetworkRetryService.retryHttpGet(
          manifestUrl,
          headers: {
            'Accept': 'application/json',
            'Cache-Control': 'no-cache',
          },
          timeout: const Duration(seconds: 15),
          config: const RetryConfig(
            maxRetries: 2,
            baseDelay: Duration(seconds: 1),
          ),
        );
        
        if (!retryResult.isSuccess || retryResult.data == null) {
          print('❌ 매니페스트 다운로드 최종 실패: ${retryResult.error}');
          return null;
        }
        
        final response = retryResult.data!;
        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body) as Map<String, dynamic>;
          final manifest = AssetManifest.fromJson(jsonData);
          print('✅ 매니페스트 로드 성공: ${manifest.gameTitle}');
          return manifest;
        } else {
          print('❌ HTTP 오류: ${response.statusCode} ${response.reasonPhrase}');
          print('📄 응답: ${response.body}');
        }
      } catch (e) {
        print('❌ 매니페스트 로드 실패: ${filterInfo.manifestUrl}');
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
}