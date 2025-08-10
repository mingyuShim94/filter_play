import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ranking_item.dart';
import '../providers/ranking_game_provider.dart';

class RankingSlotPanel extends ConsumerWidget {
  final VoidCallback? onSlotTap;

  const RankingSlotPanel({
    super.key,
    this.onSlotTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingSlots = ref.watch(rankingSlotsProvider);
    final gameProgress = ref.watch(rankingGameProgressProvider);
    
    return Container(
      width: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.black.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withValues(alpha: 0.7),
                ],
              ),
            ),
            child: Column(
              children: [
                const Text(
                  '랭킹',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(gameProgress * 10).toInt()}/10',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // 진행률 바
          Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: LinearProgressIndicator(
              value: gameProgress,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 랭킹 슬롯들
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: 10,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: RankingSlotWidget(
                    rank: index + 1,
                    item: rankingSlots[index],
                    onTap: () {
                      ref.read(rankingGameProvider.notifier).placeItemAtRank(index);
                      onSlotTap?.call();
                    },
                    onLongPress: () {
                      // 길게 누르면 아이템 제거 (재배치 기능)
                      if (rankingSlots[index] != null) {
                        ref.read(rankingGameProvider.notifier).removeItemFromRank(index);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class RankingSlotWidget extends StatelessWidget {
  final int rank;
  final RankingItem? item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const RankingSlotWidget({
    super.key,
    required this.rank,
    this.item,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = item == null;
    final rankColor = _getRankColor(rank);
    
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 50,
        decoration: BoxDecoration(
          gradient: isEmpty
              ? LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.1),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                )
              : LinearGradient(
                  colors: [
                    rankColor.withValues(alpha: 0.8),
                    rankColor.withValues(alpha: 0.6),
                  ],
                ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEmpty 
                ? Colors.white24 
                : rankColor,
            width: isEmpty ? 1 : 2,
          ),
          boxShadow: isEmpty
              ? null
              : [
                  BoxShadow(
                    color: rankColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // 순위 번호
            Container(
              width: 30,
              alignment: Alignment.center,
              child: Text(
                '$rank',
                style: TextStyle(
                  color: isEmpty ? Colors.white60 : Colors.white,
                  fontSize: 14,
                  fontWeight: isEmpty ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ),
            
            // 구분선
            Container(
              width: 1,
              height: 30,
              color: isEmpty ? Colors.white24 : Colors.white30,
            ),
            
            // 아이템 영역
            Expanded(
              child: Container(
                alignment: Alignment.center,
                child: isEmpty
                    ? Icon(
                        Icons.add,
                        color: Colors.white30,
                        size: 20,
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 이미지 표시 (이모지 대신)
                          item!.imagePath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.asset(
                                    item!.imagePath!,
                                    width: 24,
                                    height: 24,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 24,
                                        height: 24,
                                        color: Colors.white24,
                                        child: const Icon(
                                          Icons.person,
                                          size: 16,
                                          color: Colors.white60,
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Container(
                                  width: 24,
                                  height: 24,
                                  color: Colors.white24,
                                  child: const Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Colors.white60,
                                  ),
                                ),
                          const SizedBox(height: 2),
                          Text(
                            item!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // 금색
      case 2:
        return const Color(0xFFC0C0C0); // 은색
      case 3:
        return const Color(0xFFCD7F32); // 동색
      case 4:
      case 5:
        return Colors.purple; // 상위권
      case 6:
      case 7:
        return Colors.blue; // 중위권
      default:
        return Colors.green; // 하위권
    }
  }
}

// 순위별 메달 아이콘 위젯 (추후 사용 가능)
class RankMedalWidget extends StatelessWidget {
  final int rank;
  final double size;

  const RankMedalWidget({
    super.key,
    required this.rank,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    String emoji;
    switch (rank) {
      case 1:
        emoji = '🥇';
        break;
      case 2:
        emoji = '🥈';
        break;
      case 3:
        emoji = '🥉';
        break;
      default:
        return Text(
          '$rank',
          style: TextStyle(
            fontSize: size * 0.6,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
    }
    
    return Text(
      emoji,
      style: TextStyle(fontSize: size),
    );
  }
}