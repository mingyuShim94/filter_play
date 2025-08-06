import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraService {
  static CameraController? _controller;
  static List<CameraDescription>? _cameras;
  static bool _isInitialized = false;
  static int _selectedCameraIndex = 0;

  // 사용 가능한 카메라 목록 가져오기 (항상 최신 정보로 업데이트)
  static Future<List<CameraDescription>> getAvailableCameras() async {
    debugPrint('getAvailableCameras 호출');
    _cameras = await availableCameras();  // 항상 새로 가져오기
    debugPrint('사용 가능한 카메라 목록: ${_cameras!.map((c) => c.lensDirection).toList()}');
    debugPrint('카메라 개수: ${_cameras!.length}');
    return _cameras!;
  }

  // 전면 카메라 찾기
  static CameraDescription? getFrontCamera() {
    if (_cameras == null) return null;
    
    try {
      return _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
    } catch (e) {
      debugPrint('Front camera not found: $e');
      return null;
    }
  }

  // 카메라 초기화 (기본적으로 전면 카메라)
  static Future<bool> initializeCamera() async {
    try {
      // 기존 컨트롤러 정리
      await disposeCamera();
      
      final cameras = await getAvailableCameras();
      debugPrint('사용 가능한 카메라: ${cameras.map((c) => c.lensDirection).toList()}');
      
      if (cameras.isEmpty) {
        debugPrint('No cameras available');
        return false;
      }

      // 전면 카메라를 기본으로 설정
      _selectedCameraIndex = cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      if (_selectedCameraIndex == -1) {
        _selectedCameraIndex = 0;
      }
      
      debugPrint('선택된 카메라 인덱스: $_selectedCameraIndex (${cameras[_selectedCameraIndex].lensDirection})');

      return await _initializeCameraWithIndex(_selectedCameraIndex);
    } catch (e) {
      debugPrint('Camera initialization failed: $e');
      _isInitialized = false;
      return false;
    }
  }

  // 특정 인덱스의 카메라로 초기화하는 내부 메서드
  static Future<bool> _initializeCameraWithIndex(int index) async {
    try {
      if (_cameras == null || _cameras!.isEmpty || index >= _cameras!.length) {
        return false;
      }

      final selectedCamera = _cameras![index];

      // 카메라 컨트롤러 생성 (example code 방식)
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.high, // example code와 동일한 고해상도
        enableAudio: false, // 오디오 비활성화 (게임용)
        imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420, // Platform 기반 설정
      );

      // 카메라 초기화
      await _controller!.initialize();
      _isInitialized = true;

      debugPrint('Camera initialized successfully');
      debugPrint('Camera: ${selectedCamera.lensDirection}');
      debugPrint('Resolution: ${_controller!.value.previewSize}');
      debugPrint('_selectedCameraIndex: $_selectedCameraIndex');
      debugPrint('_cameras 길이: ${_cameras?.length}');
      debugPrint('canToggleCamera: ${canToggleCamera}');
      
      return true;
    } catch (e) {
      debugPrint('Camera initialization failed: $e');
      _isInitialized = false;
      return false;
    }
  }

  // 카메라 컨트롤러 가져오기
  static CameraController? get controller => _controller;

  // 카메라 초기화 상태 확인
  static bool get isInitialized => _isInitialized && 
      _controller != null && 
      _controller!.value.isInitialized;

  // 카메라 미리보기 크기 가져오기
  static Size? get previewSize => _controller?.value.previewSize;

  // 카메라 해상도 가져오기
  static Size? get resolution {
    if (!isInitialized) return null;
    return _controller!.value.previewSize;
  }

  // 현재 카메라 방향 가져오기
  static CameraLensDirection? get lensDirection {
    if (_cameras == null || _selectedCameraIndex >= _cameras!.length) return null;
    return _cameras![_selectedCameraIndex].lensDirection;
  }

  // 현재 카메라 인덱스 가져오기
  static int get currentCameraIndex => _selectedCameraIndex;

  // 사용 가능한 카메라 수 가져오기
  static int get cameraCount => _cameras?.length ?? 0;

  // 카메라 전환 가능 여부 확인
  static bool get canToggleCamera {
    final count = cameraCount;
    debugPrint('canToggleCamera 체크: 카메라 수=$count, _cameras=${_cameras?.map((c) => c.lensDirection).toList()}');
    return count > 1;
  }

  // 카메라 전환 (전면 ↔ 후면) - Example code 방식으로 단순화
  static Future<bool> toggleCamera() async {
    debugPrint('CameraService.toggleCamera 시작');
    
    // 카메라 목록이 없으면 다시 가져오기
    if (_cameras == null) {
      await getAvailableCameras();
    }
    
    debugPrint('_cameras 길이: ${_cameras?.length}');
    debugPrint('현재 _selectedCameraIndex: $_selectedCameraIndex');
    
    // Example code와 동일한 체크 방식
    if (_cameras == null || _cameras!.isEmpty || _cameras!.length < 2) {
      debugPrint('Can\'t toggle camera. not enough cameras available');
      return false;
    }

    try {
      // 이미지 스트림이 진행 중이면 먼저 중지 (Example code와 동일)
      if (_controller != null && _controller!.value.isStreamingImages) {
        debugPrint('이미지 스트림 중지...');
        await stopImageStream();
      }

      // 다음 카메라 인덱스 계산 (Example code와 동일)
      final oldIndex = _selectedCameraIndex;
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
      debugPrint('카메라 인덱스 변경: $oldIndex → $_selectedCameraIndex');

      // 새 카메라로 초기화 (Example code와 동일한 방식)
      debugPrint('새 카메라로 초기화 시도...');
      final success = await _initializeCameraWithIndex(_selectedCameraIndex);
      
      debugPrint('Camera toggled to: ${_cameras![_selectedCameraIndex].lensDirection}');
      debugPrint('초기화 결과: $success');
      return success;
    } catch (e) {
      debugPrint('Failed to toggle camera: $e');
      return false;
    }
  }

  // 카메라 이미지 스트림 시작 (ML Kit용)
  static Future<void> startImageStream(Function(CameraImage) onImageAvailable) async {
    if (!isInitialized) {
      debugPrint('Camera not initialized for image stream');
      return;
    }

    try {
      await _controller!.startImageStream(onImageAvailable);
      debugPrint('Image stream started');
    } catch (e) {
      debugPrint('Failed to start image stream: $e');
    }
  }

  // 카메라 이미지 스트림 중지
  static Future<void> stopImageStream() async {
    if (!isInitialized) return;

    try {
      await _controller!.stopImageStream();
      debugPrint('Image stream stopped');
    } catch (e) {
      debugPrint('Failed to stop image stream: $e');
    }
  }

  // 카메라 리소스 정리
  static Future<void> disposeCamera() async {
    if (_controller != null) {
      try {
        if (_controller!.value.isStreamingImages) {
          await _controller!.stopImageStream();
        }
        await _controller!.dispose();
        debugPrint('Camera disposed successfully');
      } catch (e) {
        debugPrint('Error disposing camera: $e');
      }
      _controller = null;
    }
    _isInitialized = false;
  }

  // 카메라 상태 정보
  static Map<String, dynamic> getCameraInfo() {
    return {
      'isInitialized': isInitialized,
      'hasController': _controller != null,
      'resolution': resolution?.toString(),
      'lensDirection': lensDirection?.toString(),
      'isStreaming': _controller?.value.isStreamingImages ?? false,
    };
  }
}