import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            content: Text('${filter.name} 다운로드가 시작되었습니다.'),
            backgroundColor: Colors.green,
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
        return AlertDialog(
          title: const Text('준비중'),
          content: Text('${filter.name} 필터는 현재 준비중입니다.\n곧 만나보실 수 있어요!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
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

            return AlertDialog(
              title: Text('${filter.name} 다운로드'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (downloadStatus == DownloadStatus.downloading) ...[
                    const Text('다운로드 중...'),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: downloadProgress),
                    const SizedBox(height: 8),
                    Text('${(downloadProgress * 100).toStringAsFixed(1)}%'),
                  ] else ...[
                    const Text('이 필터를 사용하려면 애셋을 다운로드해야 합니다.'),
                    const SizedBox(height: 16),
                    FutureBuilder<double>(
                      future: assetNotifier.getDownloadSize(filter.id),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data! > 0) {
                          return Text('다운로드 크기: ${assetNotifier.formatFileSize(snapshot.data!)}');
                        }
                        return const Text('크기 계산 중...');
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
                    child: const Text('취소'),
                  ),
                ] else ...[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('나중에'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _startDownload(context, ref, filter);
                    },
                    child: const Text('다운로드'),
                  ),
                ],
              ],
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
        return AlertDialog(
          title: const Text('오류'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filterState = ref.watch(filterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentCategory?.name ?? '필터 선택'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 필터 목록 제목
            Text(
              '필터 선택',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // 필터 목록
            Expanded(
              child: filterState.isLoading || _currentCategory == null
                  ? const Center(child: CircularProgressIndicator())
                  : (_currentCategory?.items.isEmpty ?? true)
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '아직 필터가 없습니다',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: Colors.grey[600],
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
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: filter.isEnabled
                ? null
                : LinearGradient(
                    colors: [
                      Colors.grey[300]!,
                      Colors.grey[200]!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
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
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey[400],
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
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: filter.isEnabled ? Colors.black87 : Colors.grey[600],
                                  ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            
                            // 필터 설명
                            Text(
                              filter.description,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: filter.isEnabled
                                        ? Colors.grey[700]
                                        : Colors.grey[500],
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
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange[300]!,
                            ),
                          ),
                          child: Text(
                            '준비중',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.orange[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                          ),
                        ),
                      ] else if (filter.manifestPath != null) ...[
                        if (downloadStatus == DownloadStatus.downloading) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue[300]!,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '다운로드 중',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                SizedBox(
                                  height: 3,
                                  child: LinearProgressIndicator(
                                    value: downloadProgress,
                                    backgroundColor: Colors.blue[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '${(downloadProgress * 100).toStringAsFixed(0)}%',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Colors.blue[700],
                                        fontSize: 9,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (downloadStatus == DownloadStatus.downloaded) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green[300]!,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 12,
                                  color: Colors.green[700],
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '완료',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (downloadStatus == DownloadStatus.failed) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red[300]!,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error,
                                  size: 12,
                                  color: Colors.red[700],
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '실패',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Colors.red[700],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (onDownload != null) ...[
                          SizedBox(
                            height: 24,
                            child: ElevatedButton.icon(
                              onPressed: onDownload,
                              icon: const Icon(Icons.download, size: 12),
                              label: const Text(
                                '다운로드',
                                style: TextStyle(fontSize: 10),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
