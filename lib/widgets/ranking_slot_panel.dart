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
    final itemCount =
        ref.watch(rankingSlotsProvider.select((slots) => slots.length));
    final actualItemCount = itemCount > 0 ? itemCount : 10;

    return SizedBox(
      width: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: actualItemCount,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Center(
                  child: RankingSlotWidget(
                    key: ValueKey('slot_$index'),
                    rank: index + 1,
                    onSlotTap: onSlotTap,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class RankingSlotWidget extends ConsumerWidget {
  final int rank;
  final VoidCallback? onSlotTap;

  static final Map<String, ui.Image> _imageInfoCache = {};
  static final Map<String, bool> _imageIsPortraitCache = {};
  static final Map<String, Widget> _preloadedImageWidgetCache = {};
  static final Set<String> _loadingImages = {};
  
  static const Duration _animationDuration = Duration(milliseconds: 300);
  static const double _containerWidth = 43.0;
  static const double _containerHeight = 43.0;
  static const BorderRadius _containerBorderRadius = BorderRadius.all(Radius.circular(12));
  static const BorderRadius _imageBorderRadius = BorderRadius.all(Radius.circular(10));
  
  static const TextStyle _rankTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );
  
  static const TextStyle _itemNameTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 8,
    fontWeight: FontWeight.bold,
    shadows: [
      Shadow(
        offset: Offset(0.4, 0.4),
        blurRadius: 0.8,
        color: Colors.black,
      ),
    ],
  );

  const RankingSlotWidget({
    super.key,
    required this.rank,
    this.onSlotTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(rankingSlotsProvider
        .select((slots) => slots.length > rank - 1 ? slots[rank - 1] : null));
    final isEmpty = item == null;

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

  Widget _buildEmptySlotLayout() {
    return SizedBox(
      width: 73,
      height: 43,
      child: Align(
        alignment: Alignment.centerRight,
        child: AnimatedContainer(
          duration: _animationDuration,
          width: _containerWidth,
          height: _containerHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.3),
                Colors.white.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: _containerBorderRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.2,
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
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedSlotLayout(WidgetRef ref, RankingItem item) {
    final rankColor = _getRankColor(rank);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 43,
          decoration: BoxDecoration(
            color: rankColor,
            borderRadius: _containerBorderRadius,
            border: Border.all(
              color: rankColor,
              width: 1.6,
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
              style: _rankTextStyle,
            ),
          ),
        ),

        const SizedBox(width: 4),

        AnimatedContainer(
          duration: _animationDuration,
          width: _containerWidth,
          height: _containerHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                rankColor.withValues(alpha: 0.8),
                rankColor.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: _containerBorderRadius,
            border: Border.all(
              color: rankColor,
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: rankColor.withValues(alpha: 0.3),
                blurRadius: 3.2,
                offset: const Offset(0, 1.6),
              ),
            ],
          ),
          child: _buildSelectedSlot(ref, item),
        ),
      ],
    );
  }

  Widget _buildSelectedSlot(WidgetRef ref, RankingItem item) {
    return ClipRRect(
      borderRadius: _imageBorderRadius,
      child: _buildItemImage(ref, item),
    );
  }

  Widget _buildItemImage(WidgetRef ref, RankingItem item) {
    if (item.assetKey != null) {
      final selectedFilter = ref.watch(selectedFilterProvider);

      if (selectedFilter != null) {
        final imagePathProvider = ref.read(getImagePathProvider);

        return FutureBuilder<ImagePathResult>(
          key: ValueKey('${selectedFilter.id}_${item.assetKey}'),
          future: imagePathProvider(selectedFilter.id, item.assetKey!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingImage();
            }

            if (snapshot.hasError) {
              return _buildFallbackImage(item);
            }

            if (snapshot.hasData) {
              final pathResult = snapshot.data!;
              Widget? imageWidget;

              if (pathResult.localPath != null) {
                final file = File(pathResult.localPath!);
                if (file.existsSync()) {
                  imageWidget = Image.file(
                    file,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildFallbackImage(item);
                    },
                  );
                }
              }

              if (imageWidget == null && pathResult.remotePath != null) {
                imageWidget = Image.network(
                  pathResult.remotePath!,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildFallbackImage(item);
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _buildLoadingImage();
                  },
                );
              }

              if (imageWidget != null) {
                return _buildConditionalCroppedImage(
                    imageWidget, pathResult, item);
              }
            }

            return _buildFallbackImage(item);
          },
        );
      }
    }

    return _buildFallbackImage(item);
  }

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

  Widget _buildLoadingImage() {
    return Container(
      color: Colors.white12,
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultIcon() {
    return Container(
      color: Colors.white24,
      child: const Icon(
        Icons.person,
        size: 26,
        color: Colors.white60,
      ),
    );
  }

  Widget _buildConditionalCroppedImage(
      Widget imageWidget, ImagePathResult pathResult, RankingItem item) {
    if (pathResult.localPath != null) {
      final file = File(pathResult.localPath!);
      if (file.existsSync()) {
        final imagePath = file.path;
        final cachedPortraitInfo = _getCachedPortraitInfo(imagePath, item);

        if (cachedPortraitInfo != null) {
          return _buildImageWithOverlay(imageWidget, item);
        }

        return FutureBuilder<ui.Image>(
          future: _getImageInfo(file, item),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return _buildImageWithOverlay(imageWidget, item);
            }
            return _buildImageWithOverlay(imageWidget, item);
          },
        );
      }
    }

    return _buildImageWithOverlay(imageWidget, item);
  }

  Widget _buildImageWithOverlay(Widget imageWidget, RankingItem item) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 43,
            height: 43,
            child: FittedBox(
              fit: BoxFit.cover,
              child: imageWidget,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 1.6,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              item.name,
              style: _itemNameTextStyle,
            ),
          ),
        ),
      ],
    );
  }

  Future<ui.Image> _getImageInfo(File imageFile, RankingItem item) async {
    final imagePath = imageFile.path;
    final cacheKey = '${item.id}_$imagePath';

    if (_imageInfoCache.containsKey(cacheKey)) {
      return _imageInfoCache[cacheKey]!;
    }

    final bytes = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

    _imageInfoCache[cacheKey] = frame.image;
    _imageIsPortraitCache[cacheKey] = frame.image.height > frame.image.width;

    return frame.image;
  }

  bool? _getCachedPortraitInfo(String imagePath, RankingItem item) {
    final cacheKey = '${item.id}_$imagePath';
    return _imageIsPortraitCache[cacheKey];
  }
  
  static void clearImageCache() {
    _imageInfoCache.clear();
    _imageIsPortraitCache.clear();
    _preloadedImageWidgetCache.clear();
    _loadingImages.clear();
  }
  
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
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      case 4:
      case 5:
        return Colors.purple;
      case 6:
      case 7:
        return Colors.blue;
      default:
        return Colors.green;
    }
  }
}

class RankMedalWidget extends StatelessWidget {
  final int rank;
  final double size;

  const RankMedalWidget({
    super.key,
    required this.rank,
    this.size = 19,
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