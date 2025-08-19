import '../models/ranking_item.dart';
import '../models/asset_manifest.dart';
import '../services/filter_data_service.dart';

class RankingDataService {
  // 동적으로 매니페스트에서 캐릭터 데이터 로드
  static Future<List<RankingItem>> getCharactersByGameId(String gameId) async {
    final manifest = await FilterDataService.getManifestByFilterId(gameId);
    if (manifest == null) {
      return [];
    }
    
    return _convertCharactersToRankingItems(manifest);
  }

  // K-pop 멤버 데이터 (하위 호환성을 위해 유지)
  static Future<List<RankingItem>> getKpopDemonHuntersCharacters() async {
    return await getCharactersByGameId('kpop_demon_hunters');
  }

  // AssetManifest의 Character를 RankingItem으로 변환
  static List<RankingItem> _convertCharactersToRankingItems(AssetManifest manifest) {
    return manifest.characters.map((character) {
      // assets에서 해당 캐릭터의 asset 정보 찾기
      final asset = manifest.getAssetByKey(character.assetKey);
      
      return RankingItem(
        id: character.id,
        name: asset?.name ?? character.id, // asset의 name 사용, 없으면 id 사용
        emoji: '', // 빈 문자열
        description: '', // 빈 문자열
        imagePath: asset != null 
            ? 'assets/images/ranking/${manifest.gameId}/${character.id}.png' // fallback용 assets 경로
            : null,
        assetKey: character.assetKey,
      );
    }).toList();
  }


  // 추가 랭킹 테마들 (향후 확장용) - 정적 유지
  static List<RankingItem> getFoodRankingItems() {
    return [
      const RankingItem(
          id: 'pizza', name: '피자', emoji: '🍕', description: '치즈가 가득한 이탈리안 피자'),
      const RankingItem(
          id: 'burger',
          name: '햄버거',
          emoji: '🍔',
          description: '육즙 가득한 비프 패티 햄버거'),
      const RankingItem(
          id: 'ramen', name: '라멘', emoji: '🍜', description: '진한 국물의 일본식 라멘'),
      const RankingItem(
          id: 'sushi', name: '스시', emoji: '🍣', description: '신선한 생선의 일본식 스시'),
      const RankingItem(
          id: 'taco', name: '타코', emoji: '🌮', description: '매콤한 멕시칸 타코'),
      const RankingItem(
          id: 'pasta', name: '파스타', emoji: '🍝', description: '크림소스 이탈리안 파스타'),
      const RankingItem(
          id: 'chicken', name: '치킨', emoji: '🍗', description: '바삭한 프라이드 치킨'),
      const RankingItem(
          id: 'icecream',
          name: '아이스크림',
          emoji: '🍦',
          description: '시원하고 달콤한 아이스크림'),
      const RankingItem(
          id: 'donut', name: '도넛', emoji: '🍩', description: '달콤한 글레이즈드 도넛'),
      const RankingItem(
          id: 'cake', name: '케이크', emoji: '🎂', description: '촉촉한 생일 케이크'),
    ];
  }

  static List<RankingItem> getMovieRankingItems() {
    return [
      const RankingItem(
          id: 'action', name: '액션', emoji: '🎬', description: '스릴 넘치는 액션 영화'),
      const RankingItem(
          id: 'comedy', name: '코미디', emoji: '😂', description: '웃음 가득한 코미디 영화'),
      const RankingItem(
          id: 'romance', name: '로맨스', emoji: '💕', description: '달콤한 로맨스 영화'),
      const RankingItem(
          id: 'horror', name: '호러', emoji: '😱', description: '무서운 호러 영화'),
      const RankingItem(
          id: 'scifi', name: 'SF', emoji: '🚀', description: '미래적인 공상과학 영화'),
      const RankingItem(
          id: 'fantasy',
          name: '판타지',
          emoji: '🧚‍♀️',
          description: '마법 가득한 판타지 영화'),
      const RankingItem(
          id: 'thriller', name: '스릴러', emoji: '🔍', description: '긴장감 넘치는 스릴러'),
      const RankingItem(
          id: 'drama', name: '드라마', emoji: '🎭', description: '감동적인 드라마 영화'),
      const RankingItem(
          id: 'animation',
          name: '애니메이션',
          emoji: '🎨',
          description: '재미있는 애니메이션'),
      const RankingItem(
          id: 'documentary',
          name: '다큐멘터리',
          emoji: '📹',
          description: '교육적인 다큐멘터리'),
    ];
  }

  // 게임 테마별 데이터 반환 (동적 + 정적 혼합)
  static Future<List<RankingItem>> getRankingItemsByTheme(String theme) async {
    switch (theme) {
      case 'kpop_demon_hunters':
        return await getKpopDemonHuntersCharacters();
      case 'food_ranking':
        return getFoodRankingItems();
      case 'movie_ranking':
        return getMovieRankingItems();
      default:
        // 동적으로 게임 ID로 검색 시도
        final items = await getCharactersByGameId(theme);
        if (items.isNotEmpty) {
          return items;
        }
        // 기본값
        return await getKpopDemonHuntersCharacters();
    }
  }

  // 테마 이름 반환 (동적 + 정적 혼합)
  static Future<String> getThemeDisplayName(String theme) async {
    switch (theme) {
      case 'kpop_demon_hunters':
        return 'K-pop 멤버 랭킹';
      case 'food_ranking':
        return '음식 랭킹';
      case 'movie_ranking':
        return '영화 장르 랭킹';
      default:
        // 동적으로 매니페스트에서 이름 찾기
        final manifest = await FilterDataService.getManifestByFilterId(theme);
        return manifest?.gameTitle ?? '랭킹 게임';
    }
  }

  // 사용 가능한 테마 목록 (동적 + 정적 혼합)
  static Future<List<String>> getAvailableThemes() async {
    final List<String> themes = [
      'kpop_demon_hunters',
      'food_ranking',
      'movie_ranking',
    ];
    
    // TODO: 향후 동적으로 매니페스트에서 추가 테마들 로드
    
    return themes;
  }
}