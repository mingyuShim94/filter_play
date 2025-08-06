import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/permission_service.dart';

// 권한 상태 모델
class PermissionState {
  final bool cameraGranted;
  final bool storageGranted;
  final bool isLoading;

  const PermissionState({
    this.cameraGranted = false,
    this.storageGranted = false,
    this.isLoading = false,
  });

  PermissionState copyWith({
    bool? cameraGranted,
    bool? storageGranted,
    bool? isLoading,
  }) {
    return PermissionState(
      cameraGranted: cameraGranted ?? this.cameraGranted,
      storageGranted: storageGranted ?? this.storageGranted,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// 권한 상태 관리 Notifier
class PermissionNotifier extends StateNotifier<PermissionState> {
  PermissionNotifier() : super(const PermissionState());

  // 초기 권한 상태 확인
  Future<void> checkInitialPermissions() async {
    state = state.copyWith(isLoading: true);

    final cameraGranted = await PermissionService.isCameraPermissionGranted();
    final storageGranted = await PermissionService.isStoragePermissionGranted();

    state = state.copyWith(
      cameraGranted: cameraGranted,
      storageGranted: storageGranted,
      isLoading: false,
    );
  }

  // 카메라 권한 상태 업데이트
  Future<bool> requestCameraPermission() async {
    state = state.copyWith(isLoading: true);

    final status = await PermissionService.requestCameraPermission();
    final granted = status == PermissionStatus.granted;

    state = state.copyWith(
      cameraGranted: granted,
      isLoading: false,
    );

    return granted;
  }

  // 저장소 권한 상태 업데이트
  Future<bool> requestStoragePermission() async {
    state = state.copyWith(isLoading: true);

    final status = await PermissionService.requestStoragePermission();
    final granted = status == PermissionStatus.granted;

    state = state.copyWith(
      storageGranted: granted,
      isLoading: false,
    );

    return granted;
  }

  // 권한 상태 새로고침
  Future<void> refreshPermissions() async {
    await checkInitialPermissions();
  }
}

// Provider 정의
final permissionProvider = StateNotifierProvider<PermissionNotifier, PermissionState>(
  (ref) => PermissionNotifier(),
);

// 편의를 위한 개별 권한 Provider들
final cameraPermissionProvider = Provider<bool>((ref) {
  return ref.watch(permissionProvider).cameraGranted;
});

final storagePermissionProvider = Provider<bool>((ref) {
  return ref.watch(permissionProvider).storageGranted;
});

final permissionLoadingProvider = Provider<bool>((ref) {
  return ref.watch(permissionProvider).isLoading;
});