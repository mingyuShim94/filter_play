import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/filter_category.dart';
import '../models/filter_item.dart';
import '../models/asset_manifest.dart';
import '../models/master_manifest.dart';
import '../services/asset_download_service.dart';

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
      return _cachedMasterManifest;
    }

    try {
      // 원격 마스터 매니페스트 다운로드 시도
      final response = await http.get(Uri.parse(_masterManifestUrl));
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        _cachedMasterManifest = MasterManifest.fromJson(jsonData);
        return _cachedMasterManifest;
      }
    } catch (e) {
      print('원격 마스터 매니페스트 로드 실패: $e');
    }

    // 폴백: 로컬 매니페스트 사용
    return await _loadFallbackMasterManifest();
  }

  /// 폴백용 로컬 마스터 매니페스트 생성
  static Future<MasterManifest?> _loadFallbackMasterManifest() async {
    try {
      // 로컬 매니페스트가 있다면 기본 마스터 매니페스트 생성
      const fallbackFilters = [
        FilterManifestInfo(
          gameId: 'all_characters',
          manifestUrl: 'assets/images/ranking/manifest.json',
          category: 'ranking',
          isEnabled: true,
        ),
      ];
      
      _cachedMasterManifest = const MasterManifest(
        version: '1.0.0',
        lastUpdated: '2024-01-01T00:00:00Z',
        baseUrl: '', // 로컬의 경우 빈 문자열
        filters: fallbackFilters,
      );
      
      return _cachedMasterManifest;
    } catch (e) {
      print('폴백 마스터 매니페스트 생성 실패: $e');
      return null;
    }
  }

  /// 마스터 매니페스트에서 랭킹 필터들을 동적으로 로드
  static Future<List<FilterItem>> _loadRankingFilters() async {
    final List<FilterItem> filters = [];
    
    final masterManifest = await _loadMasterManifest();
    if (masterManifest == null) {
      return filters;
    }

    // 랭킹 카테고리 필터들만 추출
    final rankingFilters = masterManifest.getFiltersByCategory('ranking');
    
    for (final filterInfo in rankingFilters) {
      if (!filterInfo.isEnabled) continue;
      
      try {
        AssetManifest manifest;
        
        if (masterManifest.baseUrl.isEmpty) {
          // 로컬 매니페스트 로드
          manifest = await AssetDownloadService.loadManifestFromAssets(filterInfo.manifestUrl);
        } else {
          // 원격 매니페스트 로드
          final manifestUrl = masterManifest.getFullManifestUrl(filterInfo.manifestUrl);
          final response = await http.get(Uri.parse(manifestUrl));
          if (response.statusCode == 200) {
            final jsonData = json.decode(response.body) as Map<String, dynamic>;
            manifest = AssetManifest.fromJson(jsonData);
          } else {
            continue;
          }
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
      } catch (e) {
        print('매니페스트 로드 실패: ${filterInfo.manifestUrl} - $e');
      }
    }
    
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
  
  /// 필터 ID로 매니페스트 로드
  static Future<AssetManifest?> getManifestByFilterId(String filterId) async {
    final masterManifest = await _loadMasterManifest();
    if (masterManifest == null) return null;

    final filterInfo = masterManifest.getFilterByGameId(filterId);
    if (filterInfo == null || !filterInfo.isEnabled) return null;

    try {
      if (masterManifest.baseUrl.isEmpty) {
        // 로컬 매니페스트 로드
        return await AssetDownloadService.loadManifestFromAssets(filterInfo.manifestUrl);
      } else {
        // 원격 매니페스트 로드
        final manifestUrl = masterManifest.getFullManifestUrl(filterInfo.manifestUrl);
        final response = await http.get(Uri.parse(manifestUrl));
        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body) as Map<String, dynamic>;
          return AssetManifest.fromJson(jsonData);
        }
      }
    } catch (e) {
      print('매니페스트 로드 실패: ${filterInfo.manifestUrl} - $e');
    }
    return null;
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