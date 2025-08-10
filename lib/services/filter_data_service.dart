import 'package:flutter/material.dart';
import '../models/filter_category.dart';
import '../models/filter_item.dart';

class FilterDataService {
  static List<FilterCategory> getFilterCategories() {
    return [
      FilterCategory(
        id: 'ranking',
        name: '랭킹 필터',
        description: '다양한 주제로 순위를 매기는 게임',
        icon: Icons.leaderboard,
        isEnabled: true,
        items: _getRankingFilters(),
      ),
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

  static List<FilterItem> _getRankingFilters() {
    return [
      const FilterItem(
        id: 'kpop_demon_hunters',
        name: '케이팝 데몬 헌터스',
        description: '케이팝데몬헌터스에서 좋아하는 캐릭터순위를 정해보세요',
        gameType: GameType.ranking,
        isEnabled: true,
      ),
      const FilterItem(
        id: 'food_ranking',
        name: '음식 랭킹',
        description: '좋아하는 음식 순위를 정해보세요',
        gameType: GameType.ranking,
        isEnabled: false,
      ),
      const FilterItem(
        id: 'movie_ranking',
        name: '영화 랭킹',
        description: '최고의 영화를 골라보세요',
        gameType: GameType.ranking,
        isEnabled: false,
      ),
      const FilterItem(
        id: 'celebrity_ranking',
        name: '연예인 랭킹',
        description: '좋아하는 연예인 순위를 매겨보세요',
        gameType: GameType.ranking,
        isEnabled: false,
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

  static FilterCategory? getCategoryById(String id) {
    final categories = getFilterCategories();
    try {
      return categories.firstWhere((category) => category.id == id);
    } catch (e) {
      return null;
    }
  }

  static FilterItem? getFilterById(String categoryId, String filterId) {
    final category = getCategoryById(categoryId);
    if (category == null) return null;

    try {
      return category.items.firstWhere((item) => item.id == filterId);
    } catch (e) {
      return null;
    }
  }
}
