import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../providers/camera_provider.dart';
import '../services/permission_service.dart';
import '../services/face_detection_service.dart';
import '../widgets/face_detection_overlay.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  // 현재 감지된 얼굴 목록
  List<Face> _currentFaces = [];
  @override
  void initState() {
    super.initState();
    // 화면 로드 후 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAll();
    });
  }

  @override
  void dispose() {
    // 화면 종료 시 리소스 정리
    // ref.read는 dispose에서 사용할 수 없으므로 직접 서비스 호출
    FaceDetectionService.dispose();
    super.dispose();
  }

  // 전체 초기화 프로세스
  Future<void> _initializeAll() async {
    // 1. FaceDetector 초기화
    final faceDetectorSuccess = await FaceDetectionService.initialize();
    if (!faceDetectorSuccess) {
      if (mounted) {
        ref.read(cameraProvider.notifier).setError('얼굴 인식 초기화에 실패했습니다');
      }
      return;
    }

    // 2. 카메라 초기화
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // 1. 먼저 카메라 권한 확인 및 요청
    if (!mounted) return;
    
    final hasPermission = await PermissionService.handleCameraPermission(context);
    if (!hasPermission) {
      // 권한이 없으면 에러 상태로 설정
      if (mounted) {
        ref.read(cameraProvider.notifier).setError('카메라 권한이 필요합니다');
      }
      return;
    }

    // 2. 권한이 있으면 카메라 초기화 진행
    final success = await ref.read(cameraProvider.notifier).initializeCamera();
    if (success) {
      // 카메라 초기화 성공 시 이미지 스트림 시작
      _startImageStream();
    }
  }

  Future<void> _startImageStream() async {
    await ref.read(cameraProvider.notifier).startImageStream(_onImageAvailable);
  }

  // 이미지 스트림 콜백 - ML Kit 얼굴 감지 실행
  Future<void> _onImageAvailable(CameraImage image) async {
    // FaceDetector가 초기화되지 않았으면 종료
    if (!FaceDetectionService.isInitialized) {
      return;
    }

    try {
      // 얼굴 감지 실행 (CameraController 전달)
      final controller = ref.read(cameraProvider).controller;
      if (controller == null) return;
      
      final faces = await FaceDetectionService.detectFaces(image, controller);
      
      // UI 업데이트를 위해 얼굴 목록 저장
      if (mounted) {
        setState(() {
          _currentFaces = faces;
        });
      }

      // 개발 단계에서 결과 출력 (나중에 제거 예정)
      if (faces.isNotEmpty) {
        FaceDetectionService.printFaceInfo(faces);
      }
      
      // TODO: Phase 2C에서 랜드마크 추출 및 입술 감지 로직 추가
      
    } catch (e) {
      // 에러는 조용히 처리 (실시간 스트림이므로 UI 방해하지 않음)
      print('얼굴 감지 에러: $e');
    }
  }

  // 카메라 전환 처리
  Future<void> _toggleCamera() async {
    print('카메라 전환 시작...');
    try {
      // 얼굴 감지 상태 초기화
      setState(() {
        _currentFaces = [];
      });

      // 카메라 전환
      print('카메라 전환 시도...');
      final success = await ref.read(cameraProvider.notifier).toggleCamera();
      print('카메라 전환 결과: $success');
      
      if (success) {
        // 카메라 전환 성공 시 이미지 스트림 재시작
        print('이미지 스트림 재시작...');
        await _startImageStream();
        print('이미지 스트림 재시작 완료');
      } else {
        print('카메라 전환 실패');
      }
    } catch (e) {
      print('카메라 전환 에러: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraProvider);
    final canToggle = ref.watch(cameraCanToggleProvider);
    final lensDirection = ref.watch(cameraLensDirectionProvider);
    final isLoading = cameraState.isLoading;
    final isInitialized = cameraState.isInitialized;
    final isStreamingImages = cameraState.isStreamingImages;
    final error = cameraState.error;
    
    // 디버깅: 카메라 전환 버튼 상태 확인
    print('카메라 전환 버튼 상태: canToggle=$canToggle, isInitialized=$isInitialized, isLoading=$isLoading, lensDirection=$lensDirection');

    return Scaffold(
      appBar: AppBar(
        title: const Text('게임 화면'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          // 카메라 전환 버튼 (항상 표시하되, 비활성 상태일 때는 회색으로)
          IconButton(
            onPressed: (canToggle && isInitialized && !isLoading) ? _toggleCamera : null,
            icon: Icon(
              lensDirection == CameraLensDirection.front
                  ? Icons.camera_front
                  : Icons.camera_rear,
              color: (canToggle && isInitialized && !isLoading) 
                  ? Colors.white 
                  : Colors.grey,
            ),
            tooltip: canToggle 
                ? (lensDirection == CameraLensDirection.front 
                    ? '후면 카메라로 전환' 
                    : '전면 카메라로 전환')
                : '카메라 전환 불가',
          ),
          
          // 카메라 상태 표시
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else if (isInitialized && isStreamingImages)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.videocam,
                  color: Colors.green,
                ),
                const SizedBox(width: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            )
          else if (isInitialized)
            const Icon(
              Icons.videocam,
              color: Colors.orange,
            )
          else
            const Icon(
              Icons.videocam_off,
              color: Colors.red,
            ),
          const SizedBox(width: 16),
        ],
      ),
      backgroundColor: Colors.black,
      body: _buildCameraBody(
          isLoading, isInitialized, error, cameraState.controller),
    );
  }

  Widget _buildCameraBody(bool isLoading, bool isInitialized, String? error,
      CameraController? controller) {
    final lensDirection = ref.watch(cameraLensDirectionProvider);
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              '카메라를 초기화하는 중...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // 권한 에러인 경우 설정 버튼도 표시
            if (error.contains('권한'))
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      ref.read(cameraProvider.notifier).clearError();
                      _initializeAll();
                    },
                    child: const Text('다시 시도'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await PermissionService.handleCameraPermission(context);
                      if (mounted) {
                        ref.read(cameraProvider.notifier).clearError();
                        _initializeAll();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('권한 설정'),
                  ),
                ],
              )
            else
              ElevatedButton(
                onPressed: () {
                  ref.read(cameraProvider.notifier).clearError();
                  _initializeAll();
                },
                child: const Text('다시 시도'),
              ),
          ],
        ),
      );
    }

    if (!isInitialized || controller == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: 80,
              color: Colors.white54,
            ),
            SizedBox(height: 16),
            Text(
              '카메라를 준비 중입니다',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // 카메라 미리보기
    return Stack(
      children: [
        // 카메라 프리뷰 - 화면에 맞게 표시
        ClipRect(
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.previewSize!.height,
                height: controller.value.previewSize!.width,
                child: CameraPreview(controller),
              ),
            ),
          ),
        ),

        // 얼굴 감지 오버레이
        if (_currentFaces.isNotEmpty)
          Positioned.fill(
            child: FaceDetectionOverlay(
              faces: _currentFaces,
              previewSize: Size(
                controller.value.previewSize!.height, // width에 height 값 (example code와 동일)
                controller.value.previewSize!.width,  // height에 width 값 (example code와 동일)
              ),
              screenSize: Size(
                MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height,
              ),
              cameraController: controller,
            ),
          ),

        // 게임 오버레이 (나중에 Phase 3에서 추가)
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      FaceDetectionService.isInitialized 
                          ? Icons.face 
                          : Icons.face_unlock_outlined,
                      color: FaceDetectionService.isInitialized 
                          ? Colors.green 
                          : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      FaceDetectionService.isInitialized 
                          ? '얼굴 인식 준비됨' 
                          : '얼굴 인식 초기화 중...',
                      style: TextStyle(
                        color: FaceDetectionService.isInitialized 
                            ? Colors.green 
                            : Colors.orange,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (FaceDetectionService.isInitialized) ...[
                      const SizedBox(width: 12),
                      Icon(
                        lensDirection == CameraLensDirection.front
                            ? Icons.camera_front
                            : Icons.camera_rear,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        lensDirection == CameraLensDirection.front ? '전면' : '후면',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _currentFaces.isEmpty
                      ? '얼굴을 화면에 맞춰주세요'
                      : '얼굴이 감지되었습니다 (${_currentFaces.length}개)',
                  style: TextStyle(
                    color: _currentFaces.isEmpty
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.green,
                    fontSize: 14,
                    fontWeight: _currentFaces.isEmpty
                        ? FontWeight.normal
                        : FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        // 게임 시작 버튼 (임시)
        Positioned(
          bottom: 50,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.purple,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Text(
                '게임 시작 (Phase 3에서 구현)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
