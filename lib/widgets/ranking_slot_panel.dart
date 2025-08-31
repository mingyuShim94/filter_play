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
<<<<<<< HEAD
    return const SizedBox(
      width: 120,
=======
    // 🔥 [최적화] 전체 리스트 대신 길이만 watch하여 리빌드 최소화
    final itemCount =
        ref.watch(rankingSlotsProvider.select((slots) => slots.length));
    final actualItemCount = itemCount > 0 ? itemCount : 10; // 초기 상태 고려

    return SizedBox(
      width: 96, // 120에서 20% 감소 (120 * 0.8 = 96)
>>>>>>> 7f08cc1a2c4439bb74914d9d688151b2a4c96c92
      child: Column(
        mainAxisSize: MainAxisSize.min, // 컨텐츠 크기에 맞춤
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
<<<<<<< HEAD
          // 랭킹 슬롯들 - 개별 Consumer로 최적화
          Expanded(
            child: _OptimizedRankingSlotsList(),
=======
          // 랭킹 슬롯들
          ListView.builder(
            shrinkWrap: true, // ListView가 컨텐츠 크기에 맞춤
            physics: const NeverScrollableScrollPhysics(), // 스크롤 비활성화
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: actualItemCount,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Center(
                  child: RankingSlotWidget(
                    key: ValueKey('slot_$index'), // 키 간소화
                    rank: index + 1,
                    onSlotTap: onSlotTap, // 콜백 전달
                  ),
                ),
              );
            },
>>>>>>> 7f08cc1a2c4439bb74914d9d688151b2a4c96c92
          ),
        ],
      ),
    );
  }
}

// 개별 슬롯별 Consumer를 통한 선택적 리빌드 최적화
class _OptimizedRankingSlotsList extends StatelessWidget {
  const _OptimizedRankingSlotsList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: List.generate(10, (index) => 
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Center(
            child: _IndividualSlotConsumer(slotIndex: index),
          ),
        ),
      ),
    );
  }
}

// 개별 슬롯용 Consumer - 해당 슬롯만 변경될 때만 리빌드
class _IndividualSlotConsumer extends ConsumerWidget {
  final int slotIndex;
  
  const _IndividualSlotConsumer({required this.slotIndex});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 특정 슬롯 인덱스만 감시하여 해당 슬롯 변경시에만 리빌드
    final slotItem = ref.watch(rankingSlotsProvider.select((slots) => 
      slotIndex < slots.length ? slots[slotIndex] : null));
    
    return RankingSlotWidget(
      key: ValueKey('slot_${slotIndex}_${slotItem?.id ?? 'empty'}'),
      rank: slotIndex + 1,
      item: slotItem,
      onTap: () {
        final rankingGame = ref.read(rankingGameProvider.notifier);
        rankingGame.placeItemAtRank(slotIndex);
        // onSlotTap 콜백은 부모에서 처리
        if (context.findAncestorWidgetOfExactType<RankingSlotPanel>()?.onSlotTap != null) {
          context.findAncestorWidgetOfExactType<RankingSlotPanel>()!.onSlotTap!();
        }
      },
      onLongPress: () {
        // 길게 누르면 아이템 제거 (재배치 기능)
        if (slotItem != null) {
          ref.read(rankingGameProvider.notifier).removeItemFromRank(slotIndex);
        }
      },
    );
  }
}

class RankingSlotWidget extends ConsumerWidget {
  final int rank;
  // final RankingItem? item; // 🔥 [제거] 더 이상 부모로부터 item을 받지 않음
  final VoidCallback? onSlotTap; // 🔥 [수정] onSlotTap 콜백을 받도록 변경

  // 이미지 정보 캐시 (깜빡임 방지)
  static final Map<String, ui.Image> _imageInfoCache = {};
  static final Map<String, bool> _imageIsPortraitCache = {};
  
  // 미리 로드된 이미지 위젯 캐시
  static final Map<String, Widget> _preloadedImageWidgetCache = {};
  
  // 이미진 로딩 상태 추적
  static final Set<String> _loadingImages = {};
  
  // 정적 상수들 - 리빌드 시 재사용
  static const Duration _animationDuration = Duration(milliseconds: 300);
  static const double _containerWidth = 54.0;
  static const double _containerHeight = 54.0;
  static const BorderRadius _containerBorderRadius = BorderRadius.all(Radius.circular(15));
  static const BorderRadius _imageBorderRadius = BorderRadius.all(Radius.circular(13));
  
  // 텍스트 스타일 상수
  static const TextStyle _rankTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );
  
  static const TextStyle _itemNameTextStyle = TextStyle(
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
  );

  const RankingSlotWidget({
    super.key,
    required this.rank,
    this.onSlotTap, // 🔥 [추가]
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🔥 [수정] 여기서 `select`를 사용하여 해당 인덱스의 아이템만 watch 합니다.
    // 이렇게 하면 다른 슬롯이 변경되어도 이 위젯은 리빌드되지 않습니다.
    final item = ref.watch(rankingSlotsProvider
        .select((slots) => slots.length > rank - 1 ? slots[rank - 1] : null));
    final isEmpty = item == null;

    // 🔥 [수정] onTap과 onLongPress 로직을 위젯 내부로 이동
    onTap() {
      ref.read(rankingGameProvider.notifier).placeItemAtRank(rank - 1);
      onSlotTap?.call();
    }

    onLongPress() {
      if (item != null) {
        ref.read(rankingGameProvider.notifier).removeItemFromRank(rank - 1);
      }
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: isEmpty
          ? _buildEmptySlotLayout()
          : _buildSelectedSlotLayout(ref, item),
    );
  }

  // 빈 슬롯 레이아웃 - 우측 정렬하여 선택된 슬롯과 이미지 위치 맞춤
  Widget _buildEmptySlotLayout() {
    return SizedBox(
      width: 73, // 26(숫자) + 4(간격) + 43(이미지)와 동일 (20% 감소)
      height: 43, // 54에서 20% 감소 (54 * 0.8 = 43.2 ≈ 43)
      child: Align(
        alignment: Alignment.centerRight,
        child: AnimatedContainer(
<<<<<<< HEAD
          duration: _animationDuration,
          width: _containerWidth,
          height: _containerHeight,
=======
          duration: const Duration(milliseconds: 300),
          width: 43, // 54에서 20% 감소 (54 * 0.8 = 43.2 ≈ 43)
          height: 43, // 54에서 20% 감소
>>>>>>> 7f08cc1a2c4439bb74914d9d688151b2a4c96c92
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.3),
                Colors.white.withValues(alpha: 0.2),
              ],
            ),
<<<<<<< HEAD
            borderRadius: _containerBorderRadius,
=======
            borderRadius: BorderRadius.circular(12), // 15에서 20% 감소 (15 * 0.8 = 12)
>>>>>>> 7f08cc1a2c4439bb74914d9d688151b2a4c96c92
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.2, // 1.5에서 20% 감소 (1.5 * 0.8 = 1.2)
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
                fontSize: 14, // 18에서 20% 감소 (18 * 0.8 = 14.4 ≈ 14)
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 선택된 슬롯 레이아웃 - Row로 숫자 영역과 이미지 영역 분리
  Widget _buildSelectedSlotLayout(WidgetRef ref, RankingItem item) {
    final rankColor = _getRankColor(rank);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 랭킹 숫자 표시 영역
        Container(
          width: 26, // 32에서 20% 감소 (32 * 0.8 = 25.6 ≈ 26)
          height: 43, // 54에서 20% 감소 (54 * 0.8 = 43.2 ≈ 43)
          decoration: BoxDecoration(
            color: rankColor,
<<<<<<< HEAD
            borderRadius: _containerBorderRadius,
=======
            borderRadius: BorderRadius.circular(12), // 15에서 20% 감소 (15 * 0.8 = 12)
>>>>>>> 7f08cc1a2c4439bb74914d9d688151b2a4c96c92
            border: Border.all(
              color: rankColor,
              width: 1.6, // 2에서 20% 감소 (2 * 0.8 = 1.6)
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
<<<<<<< HEAD
              style: _rankTextStyle,
=======
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14, // 18에서 20% 감소 (18 * 0.8 = 14.4 ≈ 14)
                fontWeight: FontWeight.bold,
              ),
>>>>>>> 7f08cc1a2c4439bb74914d9d688151b2a4c96c92
            ),
          ),
        ),

        const SizedBox(width: 4), // 5에서 20% 감소 (5 * 0.8 = 4)

        // 이미지 슬롯 영역

        AnimatedContainer(
<<<<<<< HEAD
          duration: _animationDuration,
          width: _containerWidth,
          height: _containerHeight,
=======
          duration: const Duration(milliseconds: 300),
          width: 43, // 54에서 20% 감소 (54 * 0.8 = 43.2 ≈ 43)
          height: 43, // 54에서 20% 감소
>>>>>>> 7f08cc1a2c4439bb74914d9d688151b2a4c96c92
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                rankColor.withValues(alpha: 0.8),
                rankColor.withValues(alpha: 0.6),
              ],
            ),
<<<<<<< HEAD
            borderRadius: _containerBorderRadius,
=======
            borderRadius: BorderRadius.circular(12), // 15에서 20% 감소 (15 * 0.8 = 12)
>>>>>>> 7f08cc1a2c4439bb74914d9d688151b2a4c96c92
            border: Border.all(
              color: rankColor,
              width: 1.6, // 2에서 20% 감소 (2 * 0.8 = 1.6)
            ),
            boxShadow: [
              BoxShadow(
                color: rankColor.withValues(alpha: 0.3),
                blurRadius: 3.2, // 4에서 20% 감소 (4 * 0.8 = 3.2)
                offset: const Offset(0, 1.6), // 2에서 20% 감소 (2 * 0.8 = 1.6)
              ),
            ],
          ),
          child: _buildSelectedSlot(ref, item),
        ),
      ],
    );
  }

  // 선택된 슬롯 UI - 이미지만 표시 (숫자는 별도 영역에서 처리)
  Widget _buildSelectedSlot(WidgetRef ref, RankingItem item) {
    return ClipRRect(
<<<<<<< HEAD
      borderRadius: _imageBorderRadius, // 컨테이너보다 살짝 작게
      child: _buildItemImage(ref),
=======
      borderRadius: BorderRadius.circular(10), // 13에서 20% 감소 (13 * 0.8 = 10.4 ≈ 10)
      child: _buildItemImage(ref, item),
>>>>>>> 7f08cc1a2c4439bb74914d9d688151b2a4c96c92
    );
  }

  // 이미지 빌드 - getImagePathProvider 사용하여 이마 위 이미지와 동일한 로직 적용
  Widget _buildItemImage(WidgetRef ref, RankingItem item) {
    if (item.assetKey != null) {
      // 현재 선택된 필터의 gameId 가져오기
      final selectedFilter = ref.watch(selectedFilterProvider);

      if (selectedFilter != null) {
        print(
            '🎯 [RankingSlot] 이미지 로딩 시작: gameId=${selectedFilter.id}, assetKey=${item.assetKey}');

        // getImagePathProvider 사용하여 이마 위 이미지와 동일한 로직 적용
        final imagePathProvider = ref.read(getImagePathProvider);

        return FutureBuilder<ImagePathResult>(
          key: ValueKey(
              '${selectedFilter.id}_${item.assetKey}'), // 필터나 아이템 변경시 재빌드 보장
          future: imagePathProvider(selectedFilter.id, item.assetKey!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              print('📍 [RankingSlot] 이미지 로딩 중...');
              return _buildLoadingImage();
            }

            if (snapshot.hasError) {
              print('❌ [RankingSlot] 이미지 로딩 에러: ${snapshot.error}');
              return _buildFallbackImage(item);
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
                      return _buildFallbackImage(item);
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
                    return _buildFallbackImage(item);
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _buildLoadingImage();
                  },
                );
              }

              // 이미지 비율에 따른 조건부 크롭핑
              if (imageWidget != null) {
                return _buildConditionalCroppedImage(
                    imageWidget, pathResult, item);
              }
            }

            print('⚠️ [RankingSlot] 모든 이미지 로딩 실패, fallback 사용');
            return _buildFallbackImage(item);
          },
        );
      } else {
        print('⚠️ [RankingSlot] selectedFilter가 null, fallback 사용');
      }
    } else {
      print('⚠️ [RankingSlot] assetKey가 null, fallback 사용');
    }

    // assetKey가 없거나 selectedFilter가 null이면 assets 이미지 시도
    return _buildFallbackImage(item);
  }

  // Fallback 이미지 (assets 또는 기본 아이콘)
  Widget _buildFallbackImage(RankingItem item) {
    if (item.imagePath != null) {
      return Image.asset(
        item.imagePath!,
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
          width: 16, // 20에서 20% 감소 (20 * 0.8 = 16)
          height: 16, // 20에서 20% 감소
          child: CircularProgressIndicator(
            strokeWidth: 1.6, // 2에서 20% 감소 (2 * 0.8 = 1.6)
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
        size: 26, // 32에서 20% 감소 (32 * 0.8 = 25.6 ≈ 26)
        color: Colors.white60,
      ),
    );
  }

  // 이미지 비율에 따른 조건부 크롭핑
  Widget _buildConditionalCroppedImage(
      Widget imageWidget, ImagePathResult pathResult, RankingItem item) {
    // 이미지 파일이 있을 때만 크기 확인 수행
    if (pathResult.localPath != null) {
      final file = File(pathResult.localPath!);
      if (file.existsSync()) {
        final imagePath = file.path;
        final cachedPortraitInfo = _getCachedPortraitInfo(imagePath, item);

        // 캐시된 정보가 있으면 즉시 적용 (깜빡임 방지)
        if (cachedPortraitInfo != null) {
          if (cachedPortraitInfo) {
            // 세로가 긴 이미지: 가로형과 동일한 자연스러운 크롭 적용
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10), // 13에서 20% 감소 (13 * 0.8 = 10.4 ≈ 10)
                  child: SizedBox(
                    width: 43, // 54에서 20% 감소 (54 * 0.8 = 43.2 ≈ 43)
                    height: 43, // 54에서 20% 감소
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
                  bottom: 1.6, // 2에서 20% 감소 (2 * 0.8 = 1.6)
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
<<<<<<< HEAD
                      item?.name ?? '',
                      style: _itemNameTextStyle,
=======
                      item.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8, // 10에서 20% 감소 (10 * 0.8 = 8)
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(0.4, 0.4), // 0.5에서 20% 감소 (0.5 * 0.8 = 0.4)
                            blurRadius: 0.8, // 1에서 20% 감소 (1 * 0.8 = 0.8)
                            color: Colors.black,
                          ),
                        ],
                      ),
>>>>>>> 7f08cc1a2c4439bb74914d9d688151b2a4c96c92
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
                  borderRadius: BorderRadius.circular(10), // 13에서 20% 감소 (13 * 0.8 = 10.4 ≈ 10)
                  child: SizedBox(
                    width: 43, // 54에서 20% 감소 (54 * 0.8 = 43.2 ≈ 43)
                    height: 43, // 54에서 20% 감소
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
                  bottom: 1.6, // 2에서 20% 감소 (2 * 0.8 = 1.6)
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
<<<<<<< HEAD
                      item?.name ?? '',
                      style: _itemNameTextStyle,
=======
                      item.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8, // 10에서 20% 감소 (10 * 0.8 = 8)
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(0.4, 0.4), // 0.5에서 20% 감소 (0.5 * 0.8 = 0.4)
                            blurRadius: 0.8, // 1에서 20% 감소 (1 * 0.8 = 0.8)
                            color: Colors.black,
                          ),
                        ],
                      ),
>>>>>>> 7f08cc1a2c4439bb74914d9d688151b2a4c96c92
                    ),
                  ),
                ),
              ],
            );
          }
        }

        // 캐시된 정보가 없을 때만 FutureBuilder 사용
        return FutureBuilder<ui.Image>(
          future: _getImageInfo(file, item),
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
                      bottom: 1.6, // 2에서 20% 감소 (2 * 0.8 = 1.6)
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Text(
                          item.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8, // 10에서 20% 감소 (10 * 0.8 = 8)
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
                      bottom: 1.6, // 2에서 20% 감소 (2 * 0.8 = 1.6)
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Text(
                          item.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8, // 10에서 20% 감소 (10 * 0.8 = 8)
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
                  borderRadius: BorderRadius.circular(10), // 13에서 20% 감소 (13 * 0.8 = 10.4 ≈ 10)
                  child: SizedBox(
                    width: 43, // 54에서 20% 감소 (54 * 0.8 = 43.2 ≈ 43)
                    height: 43, // 54에서 20% 감소
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
                  bottom: 1.6, // 2에서 20% 감소 (2 * 0.8 = 1.6)
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
<<<<<<< HEAD
                      item?.name ?? '',
                      style: _itemNameTextStyle,
=======
                      item.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8, // 10에서 20% 감소 (10 * 0.8 = 8)
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(0.4, 0.4), // 0.5에서 20% 감소 (0.5 * 0.8 = 0.4)
                            blurRadius: 0.8, // 1에서 20% 감소 (1 * 0.8 = 0.8)
                            color: Colors.black,
                          ),
                        ],
                      ),
>>>>>>> 7f08cc1a2c4439bb74914d9d688151b2a4c96c92
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
          borderRadius: BorderRadius.circular(10), // 13에서 20% 감소 (13 * 0.8 = 10.4 ≈ 10)
          child: SizedBox(
            width: 43, // 54에서 20% 감소 (54 * 0.8 = 43.2 ≈ 43)
            height: 43, // 54에서 20% 감소
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
              item.name,
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
  Future<ui.Image> _getImageInfo(File imageFile, RankingItem item) async {
    final imagePath = imageFile.path;
    final cacheKey = '${item.id}_$imagePath';

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
  bool? _getCachedPortraitInfo(String imagePath, RankingItem item) {
    final cacheKey = '${item.id}_$imagePath';
    return _imageIsPortraitCache[cacheKey];
  }
  
  // 캐시 정리 메서드 (메모리 관리를 위한 선택적 호출)
  static void clearImageCache() {
    _imageInfoCache.clear();
    _imageIsPortraitCache.clear();
    _preloadedImageWidgetCache.clear();
    _loadingImages.clear();
  }
  
  // 특정 아이템의 캐시만 제거
  static void clearCacheForItem(String itemId) {
    final keysToRemove = <String>[];
    
    for (final key in _imageInfoCache.keys) {
      if (key.startsWith(itemId)) keysToRemove.add(key);
    }
    for (final key in _imageIsPortraitCache.keys) {
      if (key.startsWith(itemId)) keysToRemove.add(key);
    }
    for (final key in _preloadedImageWidgetCache.keys) {
      if (key.contains(itemId)) keysToRemove.add(key);
    }
    
    for (final key in keysToRemove) {
      _imageInfoCache.remove(key);
      _imageIsPortraitCache.remove(key);
      _preloadedImageWidgetCache.remove(key);
    }
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
    this.size = 19, // 24에서 20% 감소 (24 * 0.8 = 19.2 ≈ 19)
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
