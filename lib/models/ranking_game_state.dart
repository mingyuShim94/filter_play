import 'ranking_item.dart';

enum RankingGameStatus {
  ready,    // 게임 준비
  playing,  // 게임 진행 중
  completed // 게임 완료
}

class RankingGameState {
  final RankingItem? currentItem;        // 현재 이마 위에 표시할 아이템
  final List<RankingItem?> rankingSlots; // 10개 랭킹 슬롯 (null = 비어있음)
  final List<RankingItem> remainingItems; // 남은 아이템들
  final RankingGameStatus status;
  final String? gameTheme;              // 게임 테마 (예: 'kpop_demon_hunters')
  
  const RankingGameState({
    this.currentItem,
    this.rankingSlots = const [null, null, null, null, null, null, null, null, null, null],
    this.remainingItems = const [],
    this.status = RankingGameStatus.ready,
    this.gameTheme,
  });

  RankingGameState copyWith({
    RankingItem? currentItem,
    List<RankingItem?>? rankingSlots,
    List<RankingItem>? remainingItems,
    RankingGameStatus? status,
    String? gameTheme,
  }) {
    return RankingGameState(
      currentItem: currentItem ?? this.currentItem,
      rankingSlots: rankingSlots ?? this.rankingSlots,
      remainingItems: remainingItems ?? this.remainingItems,
      status: status ?? this.status,
      gameTheme: gameTheme ?? this.gameTheme,
    );
  }

  // 게임 완료 여부 확인
  bool get isGameComplete => 
      status == RankingGameStatus.completed ||
      (rankingSlots.where((slot) => slot != null).length == 10 && currentItem == null);

  // 게임 진행률 (0.0 - 1.0)
  double get progress {
    final placedItems = rankingSlots.where((slot) => slot != null).length;
    return placedItems / 10.0;
  }

  // 비어있는 슬롯 개수
  int get emptySlots => rankingSlots.where((slot) => slot == null).length;

  // 채워진 슬롯 개수
  int get filledSlots => rankingSlots.where((slot) => slot != null).length;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RankingGameState &&
        other.currentItem == currentItem &&
        _listEquals(other.rankingSlots, rankingSlots) &&
        _listEquals(other.remainingItems, remainingItems) &&
        other.status == status &&
        other.gameTheme == gameTheme;
  }

  @override
  int get hashCode {
    return currentItem.hashCode ^
        rankingSlots.hashCode ^
        remainingItems.hashCode ^
        status.hashCode ^
        gameTheme.hashCode;
  }

  @override
  String toString() {
    return 'RankingGameState('
        'currentItem: $currentItem, '
        'filledSlots: $filledSlots/10, '
        'remainingItems: ${remainingItems.length}, '
        'status: $status, '
        'gameTheme: $gameTheme'
        ')';
  }

  // 리스트 비교 헬퍼 함수
  bool _listEquals<T>(List<T> list1, List<T> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }
}