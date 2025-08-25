import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ranking_item.dart';
import '../providers/ranking_game_provider.dart';
import '../providers/filter_provider.dart';
import '../providers/image_path_provider.dart';

class RankingSlotPanel extends ConsumerWidget {
  final VoidCallback? onSlotTap;

  const RankingSlotPanel({
    super.key,
    this.onSlotTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingSlots = ref.watch(rankingSlotsProvider);

    return SizedBox(
      width: 120,
      child: Column(
        children: [
          // 랭킹 슬롯들
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: 10,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Center(
                    child: RankingSlotWidget(
                      key: ValueKey(
                          'slot_${index}_${rankingSlots[index]?.id ?? 'empty'}'),
                      rank: index + 1,
                      item: rankingSlots[index],
                      onTap: () {
                        ref
                            .read(rankingGameProvider.notifier)
                            .placeItemAtRank(index);
                        onSlotTap?.call();
                      },
                      onLongPress: () {
                        // 길게 누르면 아이템 제거 (재배치 기능)
                        if (rankingSlots[index] != null) {
                          ref
                              .read(rankingGameProvider.notifier)
                              .removeItemFromRank(index);
                        }
                      },
                    ),
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

class RankingSlotWidget extends ConsumerWidget {
  final int rank;
  final RankingItem? item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  // 이미지 정보 캐시 (깜빡임 방지)
  static final Map<String, ui.Image> _imageInfoCache = {};
  static final Map<String, bool> _imageIsPortraitCache = {};

  const RankingSlotWidget({
    super.key,
    required this.rank,
    this.item,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEmpty = item == null;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: isEmpty ? _buildEmptySlotLayout() : _buildSelectedSlotLayout(ref),
    );
  }

  // 빈 슬롯 레이아웃 - 우측 정렬하여 선택된 슬롯과 이미지 위치 맞춤
  Widget _buildEmptySlotLayout() {
    return SizedBox(
      width: 97, // 36(숫자) + 7(간격) + 54(이미지)와 동일 (10% 축소)
      height: 54,
      child: Align(
        alignment: Alignment.centerRight,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.3),
                Colors.white.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$rank',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 선택된 슬롯 레이아웃 - Row로 숫자 영역과 이미지 영역 분리
  Widget _buildSelectedSlotLayout(WidgetRef ref) {
    final rankColor = _getRankColor(rank);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 랭킹 숫자 표시 영역
        Container(
          width: 36,
          height: 54,
          decoration: BoxDecoration(
            color: rankColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: rankColor,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: rankColor.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(width: 7),

        // 이미지 슬롯 영역
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                rankColor.withValues(alpha: 0.8),
                rankColor.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: rankColor,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: rankColor.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildSelectedSlot(ref),
        ),
      ],
    );
  }

  // 선택된 슬롯 UI - 이미지만 표시 (숫자는 별도 영역에서 처리)
  Widget _buildSelectedSlot(WidgetRef ref) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(13), // 컨테이너보다 살짝 작게
      child: _buildItemImage(ref),
    );
  }

  // 이미지 빌드 - getImagePathProvider 사용하여 이마 위 이미지와 동일한 로직 적용
  Widget _buildItemImage(WidgetRef ref) {
    if (item?.assetKey != null) {
      // 현재 선택된 필터의 gameId 가져오기
      final selectedFilter = ref.watch(selectedFilterProvider);

      if (selectedFilter != null) {
        print(
            '🎯 [RankingSlot] 이미지 로딩 시작: gameId=${selectedFilter.id}, assetKey=${item!.assetKey}');

        // getImagePathProvider 사용하여 이마 위 이미지와 동일한 로직 적용
        final imagePathProvider = ref.read(getImagePathProvider);

        return FutureBuilder<ImagePathResult>(
          key: ValueKey(
              '${selectedFilter.id}_${item!.assetKey}'), // 필터나 아이템 변경시 재빌드 보장
          future: imagePathProvider(selectedFilter.id, item!.assetKey!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              print('📍 [RankingSlot] 이미지 로딩 중...');
              return _buildLoadingImage();
            }

            if (snapshot.hasError) {
              print('❌ [RankingSlot] 이미지 로딩 에러: ${snapshot.error}');
              return _buildFallbackImage();
            }

            if (snapshot.hasData) {
              final pathResult = snapshot.data!;
              print(
                  '✅ [RankingSlot] 이미지 경로 결과: local=${pathResult.localPath}, remote=${pathResult.remotePath}');

              Widget? imageWidget;

              // 로컬 이미지 우선 시도
              if (pathResult.localPath != null) {
                final file = File(pathResult.localPath!);
                if (file.existsSync()) {
                  print('✅ [RankingSlot] 로컬 이미지 사용: ${pathResult.localPath}');
                  imageWidget = Image.file(
                    file,
                    errorBuilder: (context, error, stackTrace) {
                      print('❌ [RankingSlot] 로컬 이미지 로딩 실패: $error');
                      return _buildFallbackImage();
                    },
                  );
                }
              }

              // 리모트 이미지 시도
              if (imageWidget == null && pathResult.remotePath != null) {
                print('🌐 [RankingSlot] 리모트 이미지 시도: ${pathResult.remotePath}');
                imageWidget = Image.network(
                  pathResult.remotePath!,
                  errorBuilder: (context, error, stackTrace) {
                    print('❌ [RankingSlot] 리모트 이미지 로딩 실패: $error');
                    return _buildFallbackImage();
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _buildLoadingImage();
                  },
                );
              }

              // 이미지 비율에 따른 조건부 크롭핑
              if (imageWidget != null) {
                return _buildConditionalCroppedImage(imageWidget, pathResult);
              }
            }

            print('⚠️ [RankingSlot] 모든 이미지 로딩 실패, fallback 사용');
            return _buildFallbackImage();
          },
        );
      } else {
        print('⚠️ [RankingSlot] selectedFilter가 null, fallback 사용');
      }
    } else {
      print('⚠️ [RankingSlot] assetKey가 null, fallback 사용');
    }

    // assetKey가 없거나 selectedFilter가 null이면 assets 이미지 시도
    return _buildFallbackImage();
  }

  // Fallback 이미지 (assets 또는 기본 아이콘)
  Widget _buildFallbackImage() {
    if (item?.imagePath != null) {
      return Image.asset(
        item!.imagePath!,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultIcon();
        },
      );
    } else {
      return _buildDefaultIcon();
    }
  }

  // 로딩 중 이미지
  Widget _buildLoadingImage() {
    return Container(
      color: Colors.white12,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
          ),
        ),
      ),
    );
  }

  // 기본 아이콘
  Widget _buildDefaultIcon() {
    return Container(
      color: Colors.white24,
      child: const Icon(
        Icons.person,
        size: 32,
        color: Colors.white60,
      ),
    );
  }

  // 이미지 비율에 따른 조건부 크롭핑
  Widget _buildConditionalCroppedImage(
      Widget imageWidget, ImagePathResult pathResult) {
    // 이미지 파일이 있을 때만 크기 확인 수행
    if (pathResult.localPath != null) {
      final file = File(pathResult.localPath!);
      if (file.existsSync()) {
        final imagePath = file.path;
        final cachedPortraitInfo = _getCachedPortraitInfo(imagePath);

        // 캐시된 정보가 있으면 즉시 적용 (깜빡임 방지)
        if (cachedPortraitInfo != null) {
          if (cachedPortraitInfo) {
            // 세로가 긴 이미지: 가로형과 동일한 자연스러운 크롭 적용
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: imageWidget,
                    ),
                  ),
                ),
                // 텍스트 오버레이
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 2,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      item?.name ?? '',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(0.5, 0.5),
                            blurRadius: 1,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // 가로가 긴 이미지나 정사각형: 자연스럽게 크롭
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: imageWidget,
                    ),
                  ),
                ),
                // 텍스트 오버레이
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 2,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      item?.name ?? '',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(0.5, 0.5),
                            blurRadius: 1,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
        }

        // 캐시된 정보가 없을 때만 FutureBuilder 사용
        return FutureBuilder<ui.Image>(
          future: _getImageInfo(file),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              final image = snapshot.data!;
              final isPortrait = image.height > image.width;

              if (isPortrait) {
                // 세로가 긴 이미지: 가로형과 동일한 자연스러운 크롭 적용
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: SizedBox(
                        width: 54,
                        height: 54,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: imageWidget,
                        ),
                      ),
                    ),
                    // 텍스트 오버레이
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 2,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Text(
                          item?.name ?? '',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(0.5, 0.5),
                                blurRadius: 1,
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                // 가로가 긴 이미지나 정사각형: 자연스럽게 크롭
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: SizedBox(
                        width: 54,
                        height: 54,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: imageWidget,
                        ),
                      ),
                    ),
                    // 텍스트 오버레이
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 2,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Text(
                          item?.name ?? '',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(0.5, 0.5),
                                blurRadius: 1,
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
            }

            // 이미지 정보 로딩 중: 이전 상태 유지를 위해 기본 크롭 적용
            // (원본 이미지가 깜빡이는 것을 방지)
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: imageWidget,
                    ),
                  ),
                ),
                // 텍스트 오버레이
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 2,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      item?.name ?? '',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(0.5, 0.5),
                            blurRadius: 1,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }
    }

    // 로컬 파일이 없는 경우 (리모트 이미지): 기본 BoxFit.cover 적용
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: SizedBox(
            width: 54,
            height: 54,
            child: FittedBox(
              fit: BoxFit.cover,
              child: imageWidget,
            ),
          ),
        ),
        // 텍스트 오버레이
        Positioned(
          left: 0,
          right: 0,
          bottom: 2,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              item?.name ?? '',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(0.5, 0.5),
                    blurRadius: 1,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 이미지 파일에서 크기 정보를 획득하는 헬퍼 메서드
  // 이미지 정보를 캐시와 함께 가져오기 (깜빡임 방지)
  Future<ui.Image> _getImageInfo(File imageFile) async {
    final imagePath = imageFile.path;
    final cacheKey = '${item?.id ?? 'unknown'}_$imagePath';

    // 이미 캐시된 정보가 있으면 즉시 반환
    if (_imageInfoCache.containsKey(cacheKey)) {
      return _imageInfoCache[cacheKey]!;
    }

    final bytes = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

    // 캐시에 저장 (이미지 정보와 세로/가로 여부 모두)
    _imageInfoCache[cacheKey] = frame.image;
    _imageIsPortraitCache[cacheKey] = frame.image.height > frame.image.width;

    return frame.image;
  }

  // 캐시된 세로/가로 정보 즉시 확인 (로딩 없이)
  bool? _getCachedPortraitInfo(String imagePath) {
    final cacheKey = '${item?.id ?? 'unknown'}_$imagePath';
    return _imageIsPortraitCache[cacheKey];
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
