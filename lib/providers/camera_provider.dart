import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';

// 카메라 상태 모델
class CameraState {
  final bool isInitialized;
  final bool isLoading;
  final bool isStreamingImages;
  final String? error;
  final CameraController? controller;
  final Size? previewSize;

  const CameraState({
    this.isInitialized = false,
    this.isLoading = false,
    this.isStreamingImages = false,
    this.error,
    this.controller,
    this.previewSize,
  });

  CameraState copyWith({
    bool? isInitialized,
    bool? isLoading,
    bool? isStreamingImages,
    String? error,
    CameraController? controller,
    Size? previewSize,
  }) {
    return CameraState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      isStreamingImages: isStreamingImages ?? this.isStreamingImages,
      error: error,
      controller: controller ?? this.controller,
      previewSize: previewSize ?? this.previewSize,
    );
  }

  // 에러 클리어
  CameraState clearError() {
    return copyWith(error: null);
  }

  @override
  String toString() {
    return 'CameraState(isInitialized: $isInitialized, isLoading: $isLoading, isStreamingImages: $isStreamingImages, error: $error)';
  }
}

// 카메라 상태 관리 Notifier
class CameraNotifier extends StateNotifier<CameraState> {
  CameraNotifier() : super(const CameraState());

  // 카메라 초기화
  Future<bool> initializeCamera() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await CameraService.initializeCamera();
      
      if (success) {
        state = state.copyWith(
          isInitialized: true,
          isLoading: false,
          controller: CameraService.controller,
          previewSize: CameraService.previewSize,
        );
        
        // Provider들이 재계산되도록 상태 강제 갱신
        print('카메라 초기화 완료 후 상태 정보:');
        print('- canToggleCamera: ${CameraService.canToggleCamera}');
        print('- lensDirection: ${CameraService.lensDirection}');
        print('- cameraCount: ${CameraService.cameraCount}');
        
        return true;
      } else {
        state = state.copyWith(
          isInitialized: false,
          isLoading: false,
          error: '카메라 초기화에 실패했습니다',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isInitialized: false,
        isLoading: false,
        error: '카메라 오류: ${e.toString()}',
      );
      return false;
    }
  }

  // 카메라 상태 새로고침
  void refreshCameraState() {
    final isInitialized = CameraService.isInitialized;
    final controller = CameraService.controller;
    final previewSize = CameraService.previewSize;

    state = state.copyWith(
      isInitialized: isInitialized,
      controller: controller,
      previewSize: previewSize,
    );
  }

  // 에러 클리어
  void clearError() {
    state = state.clearError();
  }

  // 에러 설정 (권한 거부 등의 경우)
  void setError(String errorMessage) {
    state = state.copyWith(
      isLoading: false,
      error: errorMessage,
    );
  }

  // 카메라 전환 (전면 ↔ 후면) - Example code 방식으로 단순화
  Future<bool> toggleCamera() async {
    print('CameraProvider.toggleCamera 시작');

    print('로딩 상태 설정...');
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 이미지 스트림 중지
      if (state.isStreamingImages) {
        print('이미지 스트림 중지...');
        await stopImageStream();
      }

      // 카메라 전환 (Example code 방식 - 조건 체크는 CameraService에서 처리)
      print('CameraService.toggleCamera 호출...');
      final success = await CameraService.toggleCamera();
      print('CameraService.toggleCamera 결과: $success');
      
      if (success) {
        print('카메라 전환 성공, 상태 업데이트...');
        state = state.copyWith(
          isInitialized: true,
          isLoading: false,
          controller: CameraService.controller,
          previewSize: CameraService.previewSize,
        );
        print('새 카메라: ${CameraService.lensDirection}');
        return true;
      } else {
        print('카메라 전환 실패');
        state = state.copyWith(
          isLoading: false,
          error: '카메라 전환에 실패했습니다',
        );
        return false;
      }
    } catch (e) {
      print('카메라 전환 예외: $e');
      state = state.copyWith(
        isLoading: false,
        error: '카메라 전환 오류: ${e.toString()}',
      );
      return false;
    }
  }

  // 이미지 스트림 시작 (ML Kit용)
  Future<bool> startImageStream(Function(CameraImage) onImageAvailable) async {
    if (!state.isInitialized) {
      return false;
    }

    try {
      await CameraService.startImageStream(onImageAvailable);
      state = state.copyWith(isStreamingImages: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        error: '이미지 스트림 시작 실패: ${e.toString()}',
      );
      return false;
    }
  }

  // 이미지 스트림 중지
  Future<void> stopImageStream() async {
    if (state.isStreamingImages) {
      try {
        await CameraService.stopImageStream();
        state = state.copyWith(isStreamingImages: false);
      } catch (e) {
        state = state.copyWith(
          error: '이미지 스트림 중지 실패: ${e.toString()}',
        );
      }
    }
  }

  // 카메라 정리
  Future<void> disposeCamera() async {
    if (state.isStreamingImages) {
      await stopImageStream();
    }
    await CameraService.disposeCamera();
    state = const CameraState();
  }

  @override
  void dispose() {
    // Notifier가 dispose될 때 카메라도 정리
    CameraService.disposeCamera();
    super.dispose();
  }
}

// Provider 정의
final cameraProvider = StateNotifierProvider<CameraNotifier, CameraState>(
  (ref) => CameraNotifier(),
);

// 편의를 위한 개별 상태 Provider들
final cameraInitializedProvider = Provider<bool>((ref) {
  return ref.watch(cameraProvider).isInitialized;
});

final cameraLoadingProvider = Provider<bool>((ref) {
  return ref.watch(cameraProvider).isLoading;
});

final cameraErrorProvider = Provider<String?>((ref) {
  return ref.watch(cameraProvider).error;
});

final cameraControllerProvider = Provider<CameraController?>((ref) {
  return ref.watch(cameraProvider).controller;
});

final cameraStreamingProvider = Provider<bool>((ref) {
  return ref.watch(cameraProvider).isStreamingImages;
});

final cameraCanToggleProvider = Provider<bool>((ref) {
  // 카메라 상태가 변경될 때마다 재계산되도록 watch 사용
  final cameraState = ref.watch(cameraProvider);
  
  // 카메라가 초기화되지 않았으면 false
  if (!cameraState.isInitialized) {
    print('cameraCanToggleProvider: false (not initialized)');
    return false;
  }
  
  final canToggle = CameraService.canToggleCamera;
  print('cameraCanToggleProvider: $canToggle (cameraCount: ${CameraService.cameraCount})');
  return canToggle;
});

final cameraLensDirectionProvider = Provider<CameraLensDirection?>((ref) {
  // 카메라 상태가 변경될 때마다 재계산되도록 watch 사용
  final cameraState = ref.watch(cameraProvider);
  
  // 카메라가 초기화되지 않았으면 null
  if (!cameraState.isInitialized) {
    print('cameraLensDirectionProvider: null (not initialized)');
    return null;
  }
  
  final direction = CameraService.lensDirection;
  print('cameraLensDirectionProvider: $direction');
  return direction;
});