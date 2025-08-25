import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/filter_category.dart';
import '../models/filter_item.dart';
import '../services/filter_data_service.dart';
import '../services/asset_cache_service.dart';
import 'asset_provider.dart';

class FilterState {
  final List<FilterCategory> categories;
  final FilterCategory? selectedCategory;
  final FilterItem? selectedFilter;
  final bool isLoading;

  const FilterState({
    this.categories = const [],
    this.selectedCategory,
    this.selectedFilter,
    this.isLoading = false,
  });

  FilterState copyWith({
    List<FilterCategory>? categories,
    FilterCategory? selectedCategory,
    FilterItem? selectedFilter,
    bool? isLoading,
  }) {
    return FilterState(
      categories: categories ?? this.categories,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilterState &&
        other.categories.length == categories.length &&
        other.selectedCategory == selectedCategory &&
        other.selectedFilter == selectedFilter &&
        other.isLoading == isLoading;
  }

  @override
  int get hashCode {
    return categories.hashCode ^
        selectedCategory.hashCode ^
        selectedFilter.hashCode ^
        isLoading.hashCode;
  }

  @override
  String toString() {
    return 'FilterState(categories: ${categories.length}, selectedCategory: ${selectedCategory?.name}, selectedFilter: ${selectedFilter?.name}, isLoading: $isLoading)';
  }
}

class FilterNotifier extends StateNotifier<FilterState> {
  FilterNotifier(this._ref) : super(const FilterState()) {
    _loadCategories();
    _setupDownloadCompleteCallback();
    _setupMasterManifestUpdateCallback();
  }

  final Ref _ref;

  void _setupDownloadCompleteCallback() {
    // AssetProvider의 다운로드 완료 콜백 설정
    final assetNotifier = _ref.read(assetProvider.notifier);
    assetNotifier.setDownloadCompleteCallback((filterId) async {
      // 다운로드 완료 시 FilterProvider 상태 새로고침
      await refreshCategories();
    });
  }

  void _setupMasterManifestUpdateCallback() {
    // FilterDataService의 마스터 매니페스트 업데이트 콜백 설정
    FilterDataService.setUpdateCallback(() async {
      // 마스터 매니페스트 업데이트 시 FilterProvider 상태 새로고침
      await refreshCategories();
    });
  }

  Future<void> _loadCategories() async {
    state = state.copyWith(isLoading: true);

    try {
      final categories = await FilterDataService.getFilterCategories();
      final updatedCategories = <FilterCategory>[];

      for (final category in categories) {
        final updatedItems = <FilterItem>[];

        for (final item in category.items) {
          final cachedItem =
              await AssetCacheService.loadFilterItemFromCache(item);
          updatedItems.add(cachedItem);
        }

        updatedCategories.add(category.copyWith(items: updatedItems));
      }

      state = state.copyWith(
        categories: updatedCategories,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void selectCategory(FilterCategory category) {
    state = state.copyWith(
      selectedCategory: category,
      selectedFilter: null, // 카테고리 변경 시 선택된 필터 초기화
    );
  }

  void selectFilter(FilterItem filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  void clearSelection() {
    state = state.copyWith(
      selectedCategory: null,
      selectedFilter: null,
    );
  }

  Future<void> refreshCategories() async {
    await _loadCategories();
  }

  Future<void> startDownload(String filterId, String manifestPath, {bool isUpdate = false}) async {
    final assetNotifier = _ref.read(assetProvider.notifier);
    await assetNotifier.startDownload(filterId, manifestPath, isUpdate: isUpdate);
    // 다운로드 시작 즉시 상태 새로고침
    await refreshCategories();
  }

  void cancelDownload(String filterId) {
    final assetNotifier = _ref.read(assetProvider.notifier);
    assetNotifier.cancelDownload(filterId);
  }

  Future<void> deleteAssets(String filterId) async {
    final assetNotifier = _ref.read(assetProvider.notifier);
    await assetNotifier.deleteAssets(filterId);
    await refreshCategories();
  }

  Future<void> retryDownload(String filterId, String manifestPath) async {
    final assetNotifier = _ref.read(assetProvider.notifier);
    await assetNotifier.retryDownload(filterId, manifestPath);
    await refreshCategories();
  }

  // 편의 메서드들
  List<FilterCategory> get enabledCategories {
    return state.categories.where((category) => category.isEnabled).toList();
  }

  List<FilterItem> get currentCategoryItems {
    return state.selectedCategory?.items ?? [];
  }

  List<FilterItem> get enabledItemsInCurrentCategory {
    return currentCategoryItems.where((item) => item.isEnabled).toList();
  }

  bool get hasSelectedCategory => state.selectedCategory != null;
  bool get hasSelectedFilter => state.selectedFilter != null;
}

// Provider 인스턴스
final filterProvider =
    StateNotifierProvider<FilterNotifier, FilterState>((ref) {
  return FilterNotifier(ref);
});

// 편의 Provider들
final enabledCategoriesProvider = Provider<List<FilterCategory>>((ref) {
  final filterState = ref.watch(filterProvider);
  return filterState.categories
      .where((category) => category.isEnabled)
      .toList();
});

final selectedCategoryProvider = Provider<FilterCategory?>((ref) {
  final filterState = ref.watch(filterProvider);
  return filterState.selectedCategory;
});

final selectedFilterProvider = Provider<FilterItem?>((ref) {
  final filterState = ref.watch(filterProvider);
  return filterState.selectedFilter;
});

final currentCategoryItemsProvider = Provider<List<FilterItem>>((ref) {
  final filterState = ref.watch(filterProvider);
  return filterState.selectedCategory?.items ?? [];
});

final enabledItemsInCurrentCategoryProvider = Provider<List<FilterItem>>((ref) {
  final items = ref.watch(currentCategoryItemsProvider);
  return items.where((item) => item.isEnabled).toList();
});
