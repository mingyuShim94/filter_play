import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme_colors.dart';
import '../models/filter_category.dart';
import '../models/filter_item.dart';
import '../providers/filter_provider.dart';
import '../providers/asset_provider.dart';
import '../services/filter_data_service.dart';
import 'ranking_filter_screen.dart';

class RankingFilterListScreen extends ConsumerStatefulWidget {
  final FilterCategory? category;

  const RankingFilterListScreen({
    super.key,
    this.category,
  });

  @override
  ConsumerState<RankingFilterListScreen> createState() =>
      _RankingFilterListScreenState();
}

class _RankingFilterListScreenState
    extends ConsumerState<RankingFilterListScreen> {
  FilterCategory? _currentCategory;

  @override
  void initState() {
    super.initState();
    _currentCategory = widget.category;
    // 카테고리가 없거나 빈 카테고리인 경우 첫 번째 카테고리를 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDefaultCategory();
    });
  }

  Future<void> _loadDefaultCategory() async {
    if (_currentCategory == null || _currentCategory!.items.isEmpty) {
      // FilterProvider가 데이터를 로드할 때까지 기다림
      await ref.read(filterProvider.notifier).refreshCategories();
      final filterState = ref.read(filterProvider);
      if (filterState.categories.isNotEmpty) {
        if (mounted) {
          setState(() {
            _currentCategory = filterState.categories.first;
          });
        }
      }
    }
  }

  Future<void> _selectFilter(
      BuildContext context, WidgetRef ref, FilterItem filter) async {
    // 선택된 필터 정보를 Provider에 저장
    ref.read(filterProvider.notifier).selectFilter(filter);

    if (!filter.isEnabled) {
      // 준비중인 필터인 경우 다이얼로그 표시
      _showComingSoonDialog(context, filter);
      return;
    }

    // AssetProvider에서 실시간 다운로드 상태 확인
    final downloadStatus = ref.read(downloadStatusProvider(filter.id));
    final isDownloaded = downloadStatus == DownloadStatus.downloaded;

    // 버전 업데이트 체크 (다운로드된 필터도 체크)
    bool needsUpdate = false;
    if (isDownloaded && filter.manifestPath != null) {
      try {
        needsUpdate = await FilterDataService.checkFilterVersionUpdate(filter.id);
      } catch (e) {
        print('⚠️ 버전 체크 실패, 기존 동작 유지: $e');
      }
    }

    // 업데이트 처리: 기존 에셋 먼저 삭제
    if (needsUpdate && filter.manifestPath != null) {
      print('🔄 필터 업데이트 시작: ${filter.name} (${filter.id})');
      try {
        // 기존 다운로드된 에셋 완전 삭제
        await ref.read(assetProvider.notifier).deleteAssets(filter.id);
        print('🗑️ 기존 에셋 삭제 완료: ${filter.id}');
      } catch (e) {
        print('❌ 기존 에셋 삭제 실패: $e');
        if (context.mounted) {
          _showErrorDialog(context, '업데이트 준비 실패: $e');
        }
        return;
      }
    }

    // 다운로드 상태 확인 (업데이트 또는 신규 다운로드)
    if ((!isDownloaded || needsUpdate) && filter.manifestPath != null) {
      // 다운로드가 필요한 경우 또는 업데이트가 필요한 경우 다운로드 다이얼로그 표시
      if (context.mounted) {
        _showDownloadDialog(context, ref, filter, isUpdate: needsUpdate);
      }
      return;
    }

    // 활성화된 필터인 경우 카메라 화면으로 이동
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const RankingFilterScreen(),
        ),
      );
    }
  }

  Future<void> _startDownload(
      BuildContext context, WidgetRef ref, FilterItem filter, {bool isUpdate = false}) async {
    if (filter.manifestPath == null) {
      _showErrorDialog(context, '다운로드 정보가 없습니다.');
      return;
    }

    try {
      await ref
          .read(filterProvider.notifier)
          .startDownload(filter.id, filter.manifestPath!, isUpdate: isUpdate);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${filter.name} ${isUpdate ? "업데이트" : "다운로드"}가 시작되었습니다.',
              style: const TextStyle(
                color: ThemeColors.neoSeoulNight,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            backgroundColor: ThemeColors.neonBladeBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 4,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, '${isUpdate ? "업데이트" : "다운로드"} 시작 실패: $e');
      }
    }
  }

  void _showComingSoonDialog(BuildContext context, FilterItem filter) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(
              backgroundColor: ThemeColors.deepPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: ThemeColors.lightLavender.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              elevation: 8,
              shadowColor: ThemeColors.hunterPink.withValues(alpha: 0.3),
            ),
          ),
          child: AlertDialog(
            title: const Text(
              '준비중',
              style: TextStyle(
                color: ThemeColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: Text(
              '${filter.name} 필터는 현재 준비중입니다.\n곧 만나보실 수 있어요!',
              style: const TextStyle(
                color: ThemeColors.lightLavender,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: ThemeColors.neonBladeBlue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDownloadDialog(
      BuildContext context, WidgetRef ref, FilterItem filter, {bool isUpdate = false}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer(
          builder: (context, ref, child) {
            final downloadProgress =
                ref.watch(downloadProgressProvider(filter.id));
            final downloadStatus = ref.watch(downloadStatusProvider(filter.id));
            final assetNotifier = ref.read(assetProvider.notifier);

            return Theme(
              data: Theme.of(context).copyWith(
                dialogTheme: DialogThemeData(
                  backgroundColor: ThemeColors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: ThemeColors.neonBladeBlue.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  elevation: 8,
                  shadowColor: ThemeColors.neonBladeBlue.withValues(alpha: 0.3),
                ),
              ),
              child: AlertDialog(
                title: Text(
                  isUpdate ? '${filter.name} 업데이트' : '${filter.name} 다운로드',
                  style: const TextStyle(
                    color: ThemeColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (downloadStatus == DownloadStatus.downloading) ...[
                      const Text(
                        '다운로드 중...',
                        style: TextStyle(
                          color: ThemeColors.lightLavender,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: downloadProgress,
                        backgroundColor:
                            ThemeColors.deepPurple.withValues(alpha: 0.5),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            ThemeColors.neonBladeBlue),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(downloadProgress * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: ThemeColors.neonBladeBlue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ] else ...[
                      Text(
                        isUpdate 
                          ? '새 버전이 있습니다. 업데이트하시겠습니까?'
                          : '이 필터를 사용하려면 애셋을 다운로드해야 합니다.',
                        style: const TextStyle(
                          color: ThemeColors.lightLavender,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<double>(
                        future: assetNotifier.getDownloadSize(filter.id),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data! > 0) {
                            return Text(
                              '다운로드 크기: ${assetNotifier.formatFileSize(snapshot.data!)}',
                              style: const TextStyle(
                                color: ThemeColors.lightLavender,
                                fontSize: 12,
                              ),
                            );
                          }
                          return const Text(
                            '크기 계산 중...',
                            style: TextStyle(
                              color: ThemeColors.mutedText,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
                actions: [
                  if (downloadStatus == DownloadStatus.downloading) ...[
                    TextButton(
                      onPressed: () {
                        ref
                            .read(filterProvider.notifier)
                            .cancelDownload(filter.id);
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: ThemeColors.hunterPink,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ] else ...[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: ThemeColors.lightLavender,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      child: const Text(
                        '나중에',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _startDownload(context, ref, filter, isUpdate: isUpdate);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeColors.neonBladeBlue,
                        foregroundColor: ThemeColors.neoSeoulNight,
                        elevation: 4,
                        shadowColor:
                            ThemeColors.neonBladeBlue.withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        isUpdate ? '업데이트' : '다운로드',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(
              backgroundColor: ThemeColors.deepPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: ThemeColors.hunterPink.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              elevation: 8,
              shadowColor: ThemeColors.hunterPink.withValues(alpha: 0.3),
            ),
          ),
          child: AlertDialog(
            title: const Text(
              '오류',
              style: TextStyle(
                color: ThemeColors.hunterPink,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: Text(
              message,
              style: const TextStyle(
                color: ThemeColors.lightLavender,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: ThemeColors.hunterPink,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filterState = ref.watch(filterProvider);

    return Scaffold(
      backgroundColor: ThemeColors.neoSeoulNight,
      appBar: AppBar(
        backgroundColor: ThemeColors.deepPurple,
        elevation: 0,
        title: Text(
          _currentCategory?.name ?? '필터 선택',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: ThemeColors.white,
            fontSize: 18,
          ),
        ),
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: ThemeColors.appBarGradient,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 필터 목록 제목
            Text(
              '필터 선택',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: ThemeColors.lightLavender,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),

            // 필터 목록
            Expanded(
              child: filterState.isLoading || _currentCategory == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: ThemeColors.neonBladeBlue,
                        strokeWidth: 3,
                      ),
                    )
                  : (_currentCategory?.items.isEmpty ?? true)
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: ThemeColors.deepPurple,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '아직 필터가 없습니다',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: ThemeColors.lightLavender,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildDynamicFilterGrid(
                          ref, _currentCategory?.items ?? []),
            ),
          ],
        ),
      ),
    );
  }

  // 동적 필터 그리드 생성 (마스터 매니페스트 캐시 사용으로 즉시 로드)
  Widget _buildDynamicFilterGrid(WidgetRef ref, List<FilterItem> filters) {
    return FutureBuilder<Map<String, int>>(
      future: _calculateGridConfig(filters),
      builder: (context, snapshot) {
        // 마스터 매니페스트가 이미 캐시되어 있어서 매우 빠르게 처리됨
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 간단한 로딩 표시
          return _buildGridWithConfig(
              ref, filters, {'columns': 1, 'aspectRatio': 160});
        }

        if (snapshot.hasError) {
          print('❌ 그리드 설정 계산 실패: ${snapshot.error}');
          // 에러 시 기본 설정 사용
          return _buildGridWithConfig(
              ref, filters, {'columns': 1, 'aspectRatio': 160});
        }

        final gridConfig = snapshot.data ?? {'columns': 1, 'aspectRatio': 160};
        return _buildGridWithConfig(ref, filters, gridConfig);
      },
    );
  }

  // 그리드 빌더 분리
  Widget _buildGridWithConfig(
      WidgetRef ref, List<FilterItem> filters, Map<String, int> gridConfig) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridConfig['columns']!,
        crossAxisSpacing: 8, // 가로형 카드에 최적화된 간격
        mainAxisSpacing: 6, // 세로 간격 단축으로 더 많은 카드 표시
        childAspectRatio: gridConfig['aspectRatio']! / 100.0,
      ),
      itemCount: filters.length,
      itemBuilder: (context, index) {
        final filter = filters[index];
        return _FilterCard(
          filter: filter,
          onTap: () => _selectFilter(context, ref, filter),
          onDownload: filter.manifestPath != null && filter.needsDownload
              ? () => _startDownload(context, ref, filter)
              : null,
        );
      },
    );
  }

  // 로컬 그리드 설정 (960x600 이미지에 최적화된 1열 레이아웃)
  Future<Map<String, int>> _calculateGridConfig(
      List<FilterItem> filters) async {
    print('📊 로컬 그리드 설정 사용: 960x600 이미지 최적화된 1열 레이아웃');

    // 로컬 UI 설정 (960x600 이미지를 위한 1열 레이아웃)
    const localUIConfig = {
      'columns': 1,        // 1열로 설정하여 가로 이미지를 화면 폭에 맞게 표시
      'aspectRatio': 160,  // 1.6 * 100 (960x600 비율)
    };

    print('✅ 로컬 UI 설정 적용: $localUIConfig');
    return localUIConfig;
  }
}

class _FilterCard extends ConsumerWidget {
  final FilterItem filter;
  final VoidCallback onTap;
  final VoidCallback? onDownload;

  const _FilterCard({
    required this.filter,
    required this.onTap,
    this.onDownload,
  });

  // 필터 ID로 썸네일 URL 가져오기
  Future<String?> _getThumbnailUrl(String filterId) async {
    try {
      final masterManifest = await FilterDataService.getMasterManifest();
      final filterInfo = masterManifest?.filters.firstWhere(
        (f) => f.gameId == filterId,
        orElse: () => throw Exception('Filter not found'),
      );
      
      if (filterInfo != null && masterManifest != null) {
        return masterManifest.getFullThumbnailUrl(filterInfo.thumbnailUrl);
      }
    } catch (e) {
      print('썸네일 URL 로드 실패: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadStatus = ref.watch(downloadStatusProvider(filter.id));
    final downloadProgress = ref.watch(downloadProgressProvider(filter.id));

    // --- '케이팝 데몬 헌터스' 테마 색상 및 스타일 ---
    const cardBackgroundColor = Color(0xFF3D2559);
    const primaryTextColor = Colors.white;
    const secondaryTextColor = Color(0xFFA095B3);
    const hunterPinkShadow = Color(0xFFE800FF);
    // ---

    return Card(
      color: cardBackgroundColor,
      elevation: 4,
      shadowColor: hunterPinkShadow.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      // Card의 경계에 맞춰 자식 위젯(이미지 등)을 잘라냅니다.
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: hunterPinkShadow.withValues(alpha: 0.1),
        highlightColor: hunterPinkShadow.withValues(alpha: 0.1),
        child: Stack(
          fit: StackFit.expand, // Stack의 자식들이 전체를 채우도록 함
          children: [
            // 1. 배경 썸네일 이미지 (동적 로딩)
            FutureBuilder<String?>(
              future: _getThumbnailUrl(filter.id),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.network(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    // 비활성화 시 필터 효과 적용
                    color: !filter.isEnabled
                        ? Colors.black.withValues(alpha: 0.5)
                        : null,
                    colorBlendMode: BlendMode.darken,
                    // 네트워크 이미지 로딩 중 표시
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.black.withValues(alpha: 0.3),
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / 
                                  loadingProgress.expectedTotalBytes!
                                : null,
                            color: ThemeColors.neonBladeBlue,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    // 이미지 로딩 실패 시 처리
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.black.withValues(alpha: 0.3),
                        child: const Icon(
                          Icons.image_not_supported,
                          color: secondaryTextColor,
                          size: 40,
                        ),
                      );
                    },
                  );
                }
                
                // 썸네일 URL을 가져오는 중이거나 실패한 경우 기본 이미지
                return Image.asset(
                  'assets/images/ranking/sample_thumnail.png',
                  fit: BoxFit.cover,
                  color: !filter.isEnabled
                      ? Colors.black.withValues(alpha: 0.5)
                      : null,
                  colorBlendMode: BlendMode.darken,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: const Icon(
                        Icons.image_not_supported,
                        color: secondaryTextColor,
                        size: 40,
                      ),
                    );
                  },
                );
              },
            ),

            // 2. 텍스트 가독성을 위한 하단 그라데이션 오버레이
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 70, // 가로형 이미지에 맞게 조정된 텍스트 영역 높이
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7), // 가로형 이미지에서 더 강한 가독성
                      Colors.black.withValues(alpha: 0.95), // 텍스트 가독성 극대화
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // 3. 필터 텍스트 정보 (이름, 설명)
            Positioned(
              bottom: 10, // 가로형 카드에 맞게 패딩 조정
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filter.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 15, // 가로형 카드에서 더 큰 제목
                      color: primaryTextColor,
                      // 가로형 이미지에서 텍스트 가독성 극대화를 위한 다중 그림자
                      shadows: [
                        const Shadow(
                          blurRadius: 6,
                          offset: Offset(0, 1),
                          color: Colors.black87,
                        ),
                        const Shadow(
                          blurRadius: 2,
                          offset: Offset(0, 0),
                          color: Colors.black54,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // 4. 상태 표시 위젯 (다운로드, 준비중 등) - 오른쪽 상단에 배치
            Positioned(
              top: 6, // 가로형 카드에 맞게 위치 조정
              right: 8,
              child: _buildStatusBadge(
                context,
                filter,
                downloadStatus,
                downloadProgress,
                onDownload,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 필터의 상태에 따라 적절한 뱃지(Badge) 위젯을 생성하여 반환합니다.
  /// 코드를 깔끔하게 유지하기 위해 별도 함수로 분리했습니다.
  Widget _buildStatusBadge(
    BuildContext context,
    FilterItem filter,
    DownloadStatus status,
    double progress,
    VoidCallback? onDownload,
  ) {
    // 준비중
    if (!filter.isEnabled) {
      return _StatusContainer(
        backgroundColor: Colors.orange.shade900.withValues(alpha: 0.8),
        child: const Text('준비중',
            style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      );
    }

    if (filter.manifestPath != null) {
      // 다운로드 중
      if (status == DownloadStatus.downloading) {
        return _StatusContainer(
          backgroundColor: Colors.black.withValues(alpha: 0.6),
          child: Column(
            children: [
              Text('${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: Color(0xFF00E0FF),
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              SizedBox(
                width: 40,
                height: 3,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade700,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF00E0FF)),
                ),
              ),
            ],
          ),
        );
      }
      // 다운로드 완료
      if (status == DownloadStatus.downloaded) {
        return _StatusContainer(
          backgroundColor:
              const Color(0xFF00E0FF).withValues(alpha: 0.8), // Neon Blade Blue
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, size: 12, color: Colors.black),
              SizedBox(width: 4),
              Text('보유중',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }
      // 다운로드 실패
      if (status == DownloadStatus.failed) {
        return _StatusContainer(
          backgroundColor:
              const Color(0xFFE800FF).withValues(alpha: 0.8), // Hunter Pink
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 12, color: Colors.white),
              SizedBox(width: 4),
              Text('실패',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }
      // 다운로드 필요
      if (onDownload != null) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onDownload,
            borderRadius: BorderRadius.circular(8),
            child: _StatusContainer(
              backgroundColor: Colors.black.withValues(alpha: 0.6),
              borderColor: const Color(0xFF00E0FF),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download, size: 12, color: Color(0xFF00E0FF)),
                  SizedBox(width: 4),
                  Text('받기',
                      style: TextStyle(
                          color: Color(0xFF00E0FF),
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        );
      }
    }

    // 아무 상태도 해당하지 않으면 빈 위젯 반환
    return const SizedBox.shrink();
  }
}

/// 상태 뱃지의 공통적인 디자인을 위한 작은 컨테이너 위젯
class _StatusContainer extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color? borderColor;

  const _StatusContainer({
    required this.child,
    required this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 6, vertical: 3), // 가로형 카드에 맞게 더 컴팩트하게
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1)
            : null,
      ),
      child: child,
    );
  }
}
