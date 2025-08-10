import '../models/ranking_item.dart';

class RankingDataService {
  
  // K-pop 멤버 데이터
  static List<RankingItem> getKpopDemonHuntersCharacters() {
    return [
      const RankingItem(
        id: 'abby',
        name: '애비',
        emoji: '',
        description: '',
        imagePath: 'assets/images/ranking/kpop_demon_hunters/abby.webp',
      ),
      const RankingItem(
        id: 'baby',
        name: '베이비',
        emoji: '',
        description: '',
        imagePath: 'assets/images/ranking/kpop_demon_hunters/baby.webp',
      ),
      const RankingItem(
        id: 'bobby',
        name: '바비',
        emoji: '',
        description: '',
        imagePath: 'assets/images/ranking/kpop_demon_hunters/bobby.webp',
      ),
      const RankingItem(
        id: 'duffy',
        name: '더피',
        emoji: '',
        description: '',
        imagePath: 'assets/images/ranking/kpop_demon_hunters/duffy.webp',
      ),
      const RankingItem(
        id: 'jinu',
        name: '진우',
        emoji: '',
        description: '',
        imagePath: 'assets/images/ranking/kpop_demon_hunters/jinu.webp',
      ),
      const RankingItem(
        id: 'mira',
        name: '미라',
        emoji: '',
        description: '',
        imagePath: 'assets/images/ranking/kpop_demon_hunters/mira.webp',
      ),
      const RankingItem(
        id: 'mystery',
        name: '미스터리',
        emoji: '',
        description: '',
        imagePath: 'assets/images/ranking/kpop_demon_hunters/mystery.webp',
      ),
      const RankingItem(
        id: 'romance',
        name: '로맨스',
        emoji: '',
        description: '',
        imagePath: 'assets/images/ranking/kpop_demon_hunters/romance.webp',
      ),
      const RankingItem(
        id: 'rumi',
        name: '루미',
        emoji: '',
        description: '',
        imagePath: 'assets/images/ranking/kpop_demon_hunters/rumi.webp',
      ),
      const RankingItem(
        id: 'zoey',
        name: '조이',
        emoji: '',
        description: '',
        imagePath: 'assets/images/ranking/kpop_demon_hunters/zoey.webp',
      ),
    ];
  }
  
  // 추가 랭킹 테마들 (향후 확장용)
  static List<RankingItem> getFoodRankingItems() {
    return [
      const RankingItem(id: 'pizza', name: '피자', emoji: '🍕', description: '치즈가 가득한 이탈리안 피자'),
      const RankingItem(id: 'burger', name: '햄버거', emoji: '🍔', description: '육즙 가득한 비프 패티 햄버거'),
      const RankingItem(id: 'ramen', name: '라멘', emoji: '🍜', description: '진한 국물의 일본식 라멘'),
      const RankingItem(id: 'sushi', name: '스시', emoji: '🍣', description: '신선한 생선의 일본식 스시'),
      const RankingItem(id: 'taco', name: '타코', emoji: '🌮', description: '매콤한 멕시칸 타코'),
      const RankingItem(id: 'pasta', name: '파스타', emoji: '🍝', description: '크림소스 이탈리안 파스타'),
      const RankingItem(id: 'chicken', name: '치킨', emoji: '🍗', description: '바삭한 프라이드 치킨'),
      const RankingItem(id: 'icecream', name: '아이스크림', emoji: '🍦', description: '시원하고 달콤한 아이스크림'),
      const RankingItem(id: 'donut', name: '도넛', emoji: '🍩', description: '달콤한 글레이즈드 도넛'),
      const RankingItem(id: 'cake', name: '케이크', emoji: '🎂', description: '촉촉한 생일 케이크'),
    ];
  }

  static List<RankingItem> getMovieRankingItems() {
    return [
      const RankingItem(id: 'action', name: '액션', emoji: '🎬', description: '스릴 넘치는 액션 영화'),
      const RankingItem(id: 'comedy', name: '코미디', emoji: '😂', description: '웃음 가득한 코미디 영화'),
      const RankingItem(id: 'romance', name: '로맨스', emoji: '💕', description: '달콤한 로맨스 영화'),
      const RankingItem(id: 'horror', name: '호러', emoji: '😱', description: '무서운 호러 영화'),
      const RankingItem(id: 'scifi', name: 'SF', emoji: '🚀', description: '미래적인 공상과학 영화'),
      const RankingItem(id: 'fantasy', name: '판타지', emoji: '🧚‍♀️', description: '마법 가득한 판타지 영화'),
      const RankingItem(id: 'thriller', name: '스릴러', emoji: '🔍', description: '긴장감 넘치는 스릴러'),
      const RankingItem(id: 'drama', name: '드라마', emoji: '🎭', description: '감동적인 드라마 영화'),
      const RankingItem(id: 'animation', name: '애니메이션', emoji: '🎨', description: '재미있는 애니메이션'),
      const RankingItem(id: 'documentary', name: '다큐멘터리', emoji: '📹', description: '교육적인 다큐멘터리'),
    ];
  }

  // 게임 테마별 데이터 반환
  static List<RankingItem> getRankingItemsByTheme(String theme) {
    switch (theme) {
      case 'kpop_demon_hunters':
        return getKpopDemonHuntersCharacters();
      case 'food_ranking':
        return getFoodRankingItems();
      case 'movie_ranking':
        return getMovieRankingItems();
      default:
        return getKpopDemonHuntersCharacters(); // 기본값
    }
  }

  // 테마 이름 반환
  static String getThemeDisplayName(String theme) {
    switch (theme) {
      case 'kpop_demon_hunters':
        return 'K-pop 멤버 랭킹';
      case 'food_ranking':
        return '음식 랭킹';
      case 'movie_ranking':
        return '영화 장르 랭킹';
      default:
        return '랭킹 게임';
    }
  }

  // 사용 가능한 테마 목록
  static List<String> getAvailableThemes() {
    return [
      'kpop_demon_hunters',
      'food_ranking',
      'movie_ranking',
    ];
  }
}