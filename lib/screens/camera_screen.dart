import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../providers/camera_provider.dart';
import '../services/permission_service.dart';
import '../services/face_detection_service.dart';
import '../services/performance_service.dart';
import '../services/lip_tracking_service.dart';
import '../services/forehead_rectangle_service.dart';
import '../widgets/face_detection_overlay.dart';
import '../widgets/performance_overlay.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  // 현재 감지된 얼굴 목록
  List<Face> _currentFaces = [];
  
  // T2C.2: 현재 감지된 입술 랜드마크 (첫 번째 얼굴)
  LipLandmarks? _currentLipLandmarks;
  
  // T2C.4: 입 상태 관리
  final MouthStateDetector _mouthStateDetector = MouthStateDetector();
  MouthState _currentMouthState = MouthState.unknown;
  
  // 이마 사각형 관리
  ForeheadRectangle? _currentForeheadRectangle;
  
  // 성능 측정 서비스
  final PerformanceService _performanceService = PerformanceService();
  
  // 성능 정보 출력용 프레임 카운터
  int _frameCount = 0;
  
  // 얼굴 감지 처리 중 플래그 (중복 처리 방지)
  bool _isProcessingFrame = false;
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
    ForeheadRectangleService.disposeTextureImage(); // 이미지 리소스 정리
    super.dispose();
  }

  // 전체 초기화 프로세스
  Future<void> _initializeAll() async {
    // 1. FaceDetector Phase 2C 모드로 초기화 (랜드마크 활성화)
    final faceDetectorSuccess = await FaceDetectionService.reinitializeForPhase2C();
    if (!faceDetectorSuccess) {
      if (mounted) {
        ref.read(cameraProvider.notifier).setError('얼굴 인식 초기화에 실패했습니다');
      }
      return;
    }

    // 2. 텍스처 이미지 백그라운드 로딩 시작 (비동기)
    ForeheadRectangleService.loadTextureImage().catchError((e) {
      if (kDebugMode) {
        print('텍스처 이미지 백그라운드 로딩 실패: $e');
      }
      return null; // 에러 시 null 반환
    });

    // 3. 카메라 초기화
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

  // 이미지 스트림 콜백 - ML Kit 얼굴 감지 실행 (최적화: 스마트 프레임 스킵핑)
  Future<void> _onImageAvailable(CameraImage image) async {
    // FaceDetector가 초기화되지 않았으면 종료
    if (!FaceDetectionService.isInitialized) {
      return;
    }
    
    // 중복 처리 방지: 이미 처리 중인 프레임이 있으면 스킵
    if (_isProcessingFrame) {
      return;
    }

    try {
      _isProcessingFrame = true;
      
      // 성능 측정 시작 (프레임 시작)
      _performanceService.startFrame();
      _performanceService.startFaceDetection();
      
      // 얼굴 감지 실행 (CameraController 전달)
      final controller = ref.read(cameraProvider).controller;
      if (controller == null) return;
      
      final faces = await FaceDetectionService.detectFaces(image, controller);
      
      // 성능 측정 완료 (얼굴 감지 완료)
      _performanceService.endFaceDetection();
      _performanceService.updateMemoryUsage();
      
      // UI 업데이트를 위해 얼굴 목록 저장 (얼굴 상태가 변경된 경우에만)
      if (mounted && (faces.length != _currentFaces.length || faces.isNotEmpty)) {
        setState(() {
          _currentFaces = faces;
        });
      }

      // T2C.2: 입술 랜드마크 추출 및 분석 (첫 번째 얼굴에 대해서만)
      LipLandmarks? lipLandmarks;
      ForeheadRectangle? foreheadRectangle;
      
      if (faces.isNotEmpty) {
        final firstFace = faces.first;
        
        // 입술 랜드마크 처리
        lipLandmarks = LipTrackingService.extractLipLandmarks(firstFace);
        
        // 이마 사각형 처리 (비동기) - controller 전달
        foreheadRectangle = await ForeheadRectangleService.calculateForeheadRectangle(firstFace, controller);
        
        // 디버깅: 입술 정보를 120프레임마다 출력 (성능 영향 최소화)
        if (kDebugMode && _frameCount % 120 == 0) {
          if (lipLandmarks.isComplete) {
            LipTrackingService.printLipLandmarks(lipLandmarks);
          }
          if (foreheadRectangle != null && foreheadRectangle.isValid) {
            ForeheadRectangleService.printForeheadRectangle(foreheadRectangle);
          }
        }
        
        // T2C.4: 입 상태 판정
        final newMouthState = lipLandmarks.getMouthState(_mouthStateDetector, _currentMouthState);
        
        // 상태 업데이트 (입술 랜드마크와 이마 사각형)
        if (mounted) {
          setState(() {
            _currentLipLandmarks = lipLandmarks;
            _currentMouthState = newMouthState; // T2C.4: 상태 업데이트
            _currentForeheadRectangle = foreheadRectangle;
          });
        }
      } else {
        // 얼굴이 감지되지 않으면 모든 데이터 초기화
        if (mounted && (_currentLipLandmarks != null || _currentForeheadRectangle != null)) {
          setState(() {
            _currentLipLandmarks = null;
            _currentMouthState = MouthState.unknown; // T2C.4: 상태도 초기화
            _currentForeheadRectangle = null;
          });
        }
      }

      // 성능 정보 주기적 출력 (디버깅용) - 60 프레임마다 출력 (테스트용)
      _frameCount++;
      if (kDebugMode && _frameCount % 60 == 0) { // kDebugMode에서만 60프레임마다 출력
        _performanceService.printPerformanceInfo();
      }
      
    } catch (e) {
      // 에러는 조용히 처리 (실시간 스트림이므로 UI 방해하지 않음)
      if (kDebugMode) print('얼굴 감지 에러: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  // 카메라 전환 처리
  Future<void> _toggleCamera() async {
    if (kDebugMode) print('카메라 전환 시작...');
    try {
      // 얼굴 감지 상태 초기화 - 모든 얼굴 관련 데이터 초기화
      setState(() {
        _currentFaces = [];
        _currentLipLandmarks = null;
        _currentMouthState = MouthState.unknown;
        _currentForeheadRectangle = null;
      });

      // 카메라 전환
      if (kDebugMode) print('카메라 전환 시도...');
      final success = await ref.read(cameraProvider.notifier).toggleCamera();
      if (kDebugMode) print('카메라 전환 결과: $success');
      
      if (success) {
        // 카메라 전환 성공 시 이미지 스트림 재시작
        if (kDebugMode) print('이미지 스트림 재시작...');
        await _startImageStream();
        if (kDebugMode) print('이미지 스트림 재시작 완료');
      } else {
        if (kDebugMode) print('카메라 전환 실패');
      }
    } catch (e) {
      if (kDebugMode) print('카메라 전환 에러: $e');
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
    
    // 디버깅: 카메라 전환 버튼 상태 확인 (최적화: kDebugMode에서만)
    if (kDebugMode) {
      print('카메라 전환 버튼 상태: canToggle=$canToggle, isInitialized=$isInitialized, isLoading=$isLoading, lensDirection=$lensDirection');
    }

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
              lipLandmarks: _currentLipLandmarks, // T2C.2: 계산된 입술 랜드마크 전달
              foreheadRectangle: _currentForeheadRectangle, // 이마 사각형 전달
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

        // 이마 사각형 상태 표시 오버레이 (우상단 상단)
        if (_currentForeheadRectangle != null && _currentForeheadRectangle!.isValid)
          Positioned(
            top: 50,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.cyan.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.cyan, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '이마 사각형',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '중심: (${_currentForeheadRectangle!.center.x.toStringAsFixed(0)}, '
                    '${_currentForeheadRectangle!.center.y.toStringAsFixed(0)})',
                    style: const TextStyle(color: Colors.yellow, fontSize: 10),
                  ),
                  Text(
                    '크기: ${_currentForeheadRectangle!.width.toStringAsFixed(0)} × '
                    '${_currentForeheadRectangle!.height.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.lightGreen, fontSize: 10),
                  ),
                  Text(
                    '회전Y: ${_currentForeheadRectangle!.rotationY.toStringAsFixed(1)}°',
                    style: const TextStyle(color: Colors.orange, fontSize: 10),
                  ),
                  Text(
                    '회전Z: ${_currentForeheadRectangle!.rotationZ.toStringAsFixed(1)}°',
                    style: const TextStyle(color: Colors.pink, fontSize: 10),
                  ),
                  Text(
                    '스케일: ${_currentForeheadRectangle!.scale.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.lightBlue, fontSize: 10),
                  ),
                  Text(
                    '이미지: ${_currentForeheadRectangle!.textureImage != null ? "로딩됨" : "없음"}',
                    style: TextStyle(
                      color: _currentForeheadRectangle!.textureImage != null 
                          ? Colors.green 
                          : Colors.red, 
                      fontSize: 10
                    ),
                  ),
                ],
              ),
            ),
          ),

        // T2C.3: 입술 거리 계산 결과 표시 오버레이 (우상단)
        if (_currentLipLandmarks != null && _currentLipLandmarks!.isComplete)
          Positioned(
            top: 180,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'T2C.4: 입술 상태',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // T2C.4: 상태에 따른 색상 표시
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getMouthStateColor(_currentMouthState),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '높이: ${_currentLipLandmarks!.lipHeight.toStringAsFixed(1)}px',
                    style: const TextStyle(color: Colors.yellow, fontSize: 10),
                  ),
                  Text(
                    '너비: ${_currentLipLandmarks!.lipWidth.toStringAsFixed(1)}px',
                    style: const TextStyle(color: Colors.yellow, fontSize: 10),
                  ),
                  const SizedBox(height: 2),
                  // 입 닫힘 인식 개선: 현재 값과 threshold 비교 표시
                  Text(
                    '정규화 H: ${_currentLipLandmarks!.normalizedLipHeight.toStringAsFixed(4)}',
                    style: TextStyle(
                      color: _getCurrentValueColor(_currentLipLandmarks!.normalizedLipHeight), 
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '정규화 W: ${_currentLipLandmarks!.normalizedLipWidth.toStringAsFixed(3)}',
                    style: const TextStyle(color: Colors.lightGreen, fontSize: 10),
                  ),
                  Text(
                    '개방률: ${_currentLipLandmarks!.lipOpenRatio.toStringAsFixed(3)}',
                    style: const TextStyle(color: Colors.orange, fontSize: 10),
                  ),
                  const SizedBox(height: 2),
                  // T2C.4: 입 상태 및 threshold 표시
                  Text(
                    '상태: ${_getMouthStateText(_currentMouthState)}',
                    style: TextStyle(
                      color: _getMouthStateColor(_currentMouthState),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_mouthStateDetector.isCalibrated) ...[
                    Text(
                      'Open: ${_mouthStateDetector.thresholds["open"]!.toStringAsFixed(4)}',
                      style: const TextStyle(color: Colors.cyan, fontSize: 9),
                    ),
                    Text(
                      'Close: ${_mouthStateDetector.thresholds["close"]!.toStringAsFixed(4)}',
                      style: const TextStyle(color: Colors.cyan, fontSize: 9),
                    ),
                  ] else
                    Text(
                      '캘리브레이션: ${(_mouthStateDetector.calibrationProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.lightBlue, fontSize: 9),
                    ),
                ],
              ),
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

        // 성능 오버레이 (우상단)
        const PositionedPerformanceOverlay(
          position: PerformanceOverlayPosition.topRight,
          showDetailed: false, // 간단 모드로 시작
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

  /// T2C.4: 입 상태에 따른 색상 반환
  Color _getMouthStateColor(MouthState state) {
    switch (state) {
      case MouthState.open:
        return Colors.green;
      case MouthState.closed:
        return Colors.red;
      case MouthState.unknown:
        return Colors.yellow;
    }
  }

  /// T2C.4: 입 상태에 따른 텍스트 반환
  String _getMouthStateText(MouthState state) {
    switch (state) {
      case MouthState.open:
        return 'OPEN';
      case MouthState.closed:
        return 'CLOSED';
      case MouthState.unknown:
        return 'UNKNOWN';
    }
  }

  /// 입 닫힘 인식 개선: 현재 normalizedHeight 값의 색상 반환
  Color _getCurrentValueColor(double normalizedHeight) {
    if (!_mouthStateDetector.isCalibrated) {
      return Colors.lightBlue; // 캘리브레이션 중
    }
    
    final thresholds = _mouthStateDetector.thresholds;
    final closeThreshold = thresholds['close']!;
    final openThreshold = thresholds['open']!;
    
    if (normalizedHeight < closeThreshold) {
      return Colors.red; // 닫힘 영역
    } else if (normalizedHeight > openThreshold) {
      return Colors.green; // 열림 영역
    } else {
      return Colors.orange; // 중간 영역 (히스테리시스 구간)
    }
  }
}
