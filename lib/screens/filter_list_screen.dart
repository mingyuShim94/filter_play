import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/filter_category.dart';
import '../models/filter_item.dart';
import '../providers/filter_provider.dart';
import 'camera_screen.dart';

class FilterListScreen extends ConsumerWidget {
  final FilterCategory category;

  const FilterListScreen({
    super.key,
    required this.category,
  });

  Future<void> _selectFilter(
      BuildContext context, WidgetRef ref, FilterItem filter) async {
    // 선택된 필터 정보를 Provider에 저장
    ref.read(filterProvider.notifier).selectFilter(filter);

    if (!filter.isEnabled) {
      // 준비중인 필터인 경우 다이얼로그 표시
      _showComingSoonDialog(context, filter);
      return;
    }

    // 활성화된 필터인 경우 카메라 화면으로 이동
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(selectedFilter: filter),
        ),
      );
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(filterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 카테고리 설명
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        category.icon,
                        size: 24,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

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
              child: filterState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : category.items.isEmpty
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
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: category.items.length,
                          itemBuilder: (context, index) {
                            final filter = category.items[index];
                            return _FilterCard(
                              filter: filter,
                              onTap: () => _selectFilter(context, ref, filter),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  final FilterItem filter;
  final VoidCallback onTap;

  const _FilterCard({
    required this.filter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 필터 아이콘 또는 이미지 영역
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: filter.isEnabled
                      ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: filter.isEnabled
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.3)
                        : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: filter.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(38),
                        child: Image.network(
                          filter.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultIcon();
                          },
                        ),
                      )
                    : _buildDefaultIcon(),
              ),
              const SizedBox(height: 12),

              // 필터 이름
              Text(
                filter.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color:
                          filter.isEnabled ? Colors.black87 : Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // 필터 설명
              Text(
                filter.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: filter.isEnabled
                          ? Colors.grey[700]
                          : Colors.grey[500],
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // 준비중 표시
              if (!filter.isEnabled) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange[300]!,
                    ),
                  ),
                  child: Text(
                    '준비중',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultIcon() {
    IconData iconData;

    switch (filter.gameType) {
      case GameType.ranking:
        iconData = Icons.leaderboard;
        break;
      case GameType.faceTracking:
        iconData = Icons.face;
        break;
      case GameType.voiceRecognition:
        iconData = Icons.mic;
        break;
      case GameType.quiz:
        iconData = Icons.quiz;
        break;
    }

    return Builder(
      builder: (context) => Icon(
        iconData,
        size: 36,
        color: filter.isEnabled
            ? Theme.of(context).primaryColor
            : Colors.grey[500],
      ),
    );
  }
}
