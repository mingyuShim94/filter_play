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
  ConsumerState<RankingFilterListScreen> createState() => _RankingFilterListScreenState();
}

class _RankingFilterListScreenState extends ConsumerState<RankingFilterListScreen> {
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
    
    // 다운로드 상태 확인
    if (!isDownloaded && filter.manifestPath != null) {
      // 다운로드가 필요한 경우 다운로드 다이얼로그 표시
      _showDownloadDialog(context, ref, filter);
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

  Future<void> _startDownload(BuildContext context, WidgetRef ref, FilterItem filter) async {
    if (filter.manifestPath == null) {
      _showErrorDialog(context, '다운로드 정보가 없습니다.');
      return;
    }

    try {
      await ref.read(filterProvider.notifier).startDownload(filter.id, filter.manifestPath!);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${filter.name} 다운로드가 시작되었습니다.',
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
        _showErrorDialog(context, '다운로드 시작 실패: $e');
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  void _showDownloadDialog(BuildContext context, WidgetRef ref, FilterItem filter) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer(
          builder: (context, ref, child) {
            final downloadProgress = ref.watch(downloadProgressProvider(filter.id));
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
                  '${filter.name} 다운로드',
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
                      backgroundColor: ThemeColors.deepPurple.withValues(alpha: 0.5),
                      valueColor: const AlwaysStoppedAnimation<Color>(ThemeColors.neonBladeBlue),
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
                    const Text(
                      '이 필터를 사용하려면 애셋을 다운로드해야 합니다.',
                      style: TextStyle(
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
                      ref.read(filterProvider.notifier).cancelDownload(filter.id);
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: ThemeColors.hunterPink,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      _startDownload(context, ref, filter);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeColors.neonBladeBlue,
                      foregroundColor: ThemeColors.neoSeoulNight,
                      elevation: 4,
                      shadowColor: ThemeColors.neonBladeBlue.withValues(alpha: 0.3),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '다운로드',
                      style: TextStyle(
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      : _buildDynamicFilterGrid(ref, _currentCategory?.items ?? []),
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
          // 간단한 로딩 표시 (마스터 매니페스트 캐시가 있으면 거의 즉시 완료)
          return _buildGridWithConfig(ref, filters, {'columns': 2, 'aspectRatio': 65});
        }
        
        if (snapshot.hasError) {
          print('❌ 그리드 설정 계산 실패: ${snapshot.error}');
          // 에러 시 기본 설정 사용
          return _buildGridWithConfig(ref, filters, {'columns': 2, 'aspectRatio': 65});
        }
        
        final gridConfig = snapshot.data ?? {'columns': 2, 'aspectRatio': 65};
        return _buildGridWithConfig(ref, filters, gridConfig);
      },
    );
  }

  // 그리드 빌더 분리
  Widget _buildGridWithConfig(WidgetRef ref, List<FilterItem> filters, Map<String, int> gridConfig) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridConfig['columns']!,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
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

  // 마스터 매니페스트에서 그리드 설정 계산 (네트워크 요청 없음)
  Future<Map<String, int>> _calculateGridConfig(List<FilterItem> filters) async {
    print('📊 그리드 설정 계산 시작: 마스터 매니페스트 defaultUIConfig 사용');

    try {
      // 마스터 매니페스트에서 기본 UI 설정 가져오기
      final masterManifest = await FilterDataService.getMasterManifest();
      
      if (masterManifest?.defaultUIConfig != null) {
        final config = masterManifest!.defaultUIConfig;
        final result = {
          'columns': config.gridColumns,
          'aspectRatio': (config.aspectRatio * 100).round(),
        };
        
        print('✅ 마스터 매니페스트 UI 설정 적용: $result');
        return result;
      } else {
        print('⚠️ 마스터 매니페스트에 defaultUIConfig 없음, 기본값 사용');
      }
    } catch (e) {
      print('❌ 마스터 매니페스트 로드 실패, 기본값 사용: $e');
    }

    // 기본값
    final result = {
      'columns': 2,
      'aspectRatio': 65, // 0.65 * 100
    };

    print('📊 기본 그리드 설정 사용: $result');
    return result;
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadStatus = ref.watch(downloadStatusProvider(filter.id));
    final downloadProgress = ref.watch(downloadProgressProvider(filter.id));
    return Card(
      elevation: 4,
      color: Colors.transparent,
      shadowColor: ThemeColors.hunterPink.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: ThemeColors.hunterPinkFaded,
        highlightColor: ThemeColors.neonBladeBlueFaded,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: filter.isEnabled
                ? ThemeColors.cardGradient
                : LinearGradient(
                    colors: [
                      ThemeColors.deepPurple.withValues(alpha: 0.4),
                      ThemeColors.neoSeoulNight.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            border: Border.all(
              color: filter.isEnabled 
                ? ThemeColors.deepPurple.withValues(alpha: 0.3)
                : ThemeColors.mutedText.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: filter.isEnabled ? ThemeColors.cardShadow : null,
          ),
          child: Column(
            children: [
              // 상단 50% - 이미지 영역
              Expanded(
                flex: 1,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/ranking/sample_thumnail.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color: ThemeColors.deepPurple.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.image_not_supported,
                            color: ThemeColors.lightLavender,
                            size: 40,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              
              // 하단 50% - 텍스트 영역
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 필터 이름과 설명
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 필터 이름
                            Text(
                              filter.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: filter.isEnabled 
                                  ? ThemeColors.white 
                                  : ThemeColors.mutedText,
                                letterSpacing: 0.2,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            
                            // 필터 설명
                            Text(
                              filter.description,
                              style: TextStyle(
                                color: filter.isEnabled
                                    ? ThemeColors.lightLavender
                                    : ThemeColors.mutedText.withValues(alpha: 0.7),
                                fontSize: 10,
                                  ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      
                      // 상태 표시
                      if (!filter.isEnabled) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ThemeColors.warning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: ThemeColors.warning.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '준비중',
                            style: const TextStyle(
                              color: ThemeColors.warning,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ] else if (filter.manifestPath != null) ...[
                        if (downloadStatus == DownloadStatus.downloading) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: ThemeColors.neonBladeBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: ThemeColors.neonBladeBlue.withValues(alpha: 0.5),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: ThemeColors.neonBladeBlue.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '다운로드 중',
                                  style: const TextStyle(
                                    color: ThemeColors.neonBladeBlue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                SizedBox(
                                  height: 3,
                                  child: LinearProgressIndicator(
                                    value: downloadProgress,
                                    backgroundColor: ThemeColors.deepPurple.withValues(alpha: 0.5),
                                    valueColor: const AlwaysStoppedAnimation<Color>(ThemeColors.neonBladeBlue),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${(downloadProgress * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: ThemeColors.neonBladeBlue.withValues(alpha: 0.8),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (downloadStatus == DownloadStatus.downloaded) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: ThemeColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: ThemeColors.success.withValues(alpha: 0.5),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: ThemeColors.success.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 12,
                                  color: ThemeColors.success,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '완료',
                                  style: const TextStyle(
                                    color: ThemeColors.success,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (downloadStatus == DownloadStatus.failed) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: ThemeColors.hunterPink.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: ThemeColors.hunterPink.withValues(alpha: 0.5),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: ThemeColors.hunterPink.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error,
                                  size: 12,
                                  color: ThemeColors.hunterPink,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '실패',
                                  style: const TextStyle(
                                    color: ThemeColors.hunterPink,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (onDownload != null) ...[
                          SizedBox(
                            height: 28,
                            child: ElevatedButton.icon(
                              onPressed: onDownload,
                              icon: const Icon(Icons.download, size: 14),
                              label: const Text(
                                '다운로드',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ThemeColors.neonBladeBlue,
                                foregroundColor: ThemeColors.neoSeoulNight,
                                elevation: 4,
                                shadowColor: ThemeColors.neonBladeBlue.withValues(alpha: 0.3),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
