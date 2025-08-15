import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ranking_item.dart';
import '../models/ranking_game_state.dart';

class RankingGameNotifier extends StateNotifier<RankingGameState> {
  RankingGameNotifier() : super(const RankingGameState());

  // 게임 시작
  void startGame(String gameTheme, List<RankingItem> items) {
    if (items.isEmpty) return;

    // 아이템을 랜덤하게 섞음
    final shuffledItems = List<RankingItem>.from(items)..shuffle();
    final firstItem = shuffledItems.first;
    final remainingItems = shuffledItems.skip(1).toList();

    state = RankingGameState(
      currentItem: firstItem,
      rankingSlots: List.filled(10, null),
      remainingItems: remainingItems,
      status: RankingGameStatus.playing,
      gameTheme: gameTheme,
    );
  }

  // 슬롯에 현재 아이템 배치
  void placeItemAtRank(int rank) {
    if (state.currentItem == null) return;
    if (rank < 0 || rank >= 10) return;
    if (state.status != RankingGameStatus.playing) return;

    // 해당 슬롯이 이미 차있는지 확인
    if (state.rankingSlots[rank] != null) {
      // 이미 차있는 슬롯에 배치하려고 하면 무시
      return;
    }

    // 현재 아이템을 해당 순위에 배치
    final newRankingSlots = List<RankingItem?>.from(state.rankingSlots);
    newRankingSlots[rank] = state.currentItem;

    RankingItem? nextItem;
    List<RankingItem> newRemainingItems = List.from(state.remainingItems);

    // 다음 아이템 설정
    if (newRemainingItems.isNotEmpty) {
      nextItem = newRemainingItems.first;
      newRemainingItems.removeAt(0);
    }

    // 게임 상태 업데이트
    final newStatus = (nextItem == null && newRemainingItems.isEmpty)
        ? RankingGameStatus.completed
        : RankingGameStatus.playing;

    state = state.copyWith(
      currentItem: nextItem,
      rankingSlots: newRankingSlots,
      remainingItems: newRemainingItems,
      status: newStatus,
    );
  }

  // 특정 슬롯의 아이템 제거 (다시 배치용)
  void removeItemFromRank(int rank) {
    if (rank < 0 || rank >= 10) return;
    if (state.rankingSlots[rank] == null) return;

    final removedItem = state.rankingSlots[rank]!;
    final newRankingSlots = List<RankingItem?>.from(state.rankingSlots);
    newRankingSlots[rank] = null;

    // 제거된 아이템을 남은 아이템 목록에 추가
    final newRemainingItems = List<RankingItem>.from(state.remainingItems);

    RankingItem? newCurrentItem = state.currentItem;

    // 현재 아이템이 없다면 제거된 아이템을 현재 아이템으로 설정
    if (newCurrentItem == null) {
      newCurrentItem = removedItem;
    } else {
      // 현재 아이템이 있다면 제거된 아이템을 남은 목록에 추가
      newRemainingItems.add(removedItem);
    }

    state = state.copyWith(
      currentItem: newCurrentItem,
      rankingSlots: newRankingSlots,
      remainingItems: newRemainingItems,
      status: RankingGameStatus.playing, // 아이템이 제거되었으므로 다시 플레이 상태로
    );
  }

  // 게임 리셋
  void resetGame() {
    state = const RankingGameState();
  }

  // 게임 일시정지/재개
  void pauseGame() {
    if (state.status == RankingGameStatus.playing) {
      state = state.copyWith(status: RankingGameStatus.ready);
    }
  }

  void resumeGame() {
    if (state.status == RankingGameStatus.ready && state.currentItem != null) {
      state = state.copyWith(status: RankingGameStatus.playing);
    }
  }

  // 디버깅용 상태 출력
  void printGameState() {
    print('=== Ranking Game State ===');
    print('Status: ${state.status}');
    print(
        'Current Item: ${state.currentItem?.name} ${state.currentItem?.emoji}');
    print('Remaining Items: ${state.remainingItems.length}');
    print('Filled Slots: ${state.filledSlots}/10');
    for (int i = 0; i < state.rankingSlots.length; i++) {
      final item = state.rankingSlots[i];
      print('Rank ${i + 1}: ${item?.emoji} ${item?.name ?? 'Empty'}');
    }
    print('========================');
  }
}

// Provider 인스턴스
final rankingGameProvider =
    StateNotifierProvider<RankingGameNotifier, RankingGameState>((ref) {
  return RankingGameNotifier();
});

// 편의 Provider들
final currentRankingItemProvider = Provider<RankingItem?>((ref) {
  return ref.watch(rankingGameProvider).currentItem;
});

final rankingSlotsProvider = Provider<List<RankingItem?>>((ref) {
  return ref.watch(rankingGameProvider).rankingSlots;
});

final rankingGameProgressProvider = Provider<double>((ref) {
  return ref.watch(rankingGameProvider).progress;
});

final isRankingGameCompleteProvider = Provider<bool>((ref) {
  return ref.watch(rankingGameProvider).isGameComplete;
});

final rankingGameStatusProvider = Provider<RankingGameStatus>((ref) {
  return ref.watch(rankingGameProvider).status;
});
