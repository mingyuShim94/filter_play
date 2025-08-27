import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import '../services/forehead_rectangle_service.dart';
import '../providers/ranking_game_provider.dart';
import '../providers/filter_provider.dart';
import '../providers/image_path_provider.dart';
import '../services/ranking_data_service.dart';
import '../widgets/ranking_slot_panel.dart';
import 'result_screen.dart';

/// RankingFilterScreen is a ranking filter page.
class RankingFilterScreen extends ConsumerStatefulWidget {
  /// Default Constructor
  const RankingFilterScreen({super.key});

  @override
  ConsumerState<RankingFilterScreen> createState() =>
      _RankingFilterScreenState();
}

class _RankingFilterScreenState extends ConsumerState<RankingFilterScreen> {
  // RepaintBoundary를 참조하기 위한 GlobalKey
  final GlobalKey _captureKey = GlobalKey();

  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: false, // 웃음 확률 등 불필요하므로 비활성화
      enableLandmarks: true, // 이마 계산에 필요한 눈, 코 랜드마크 활성화
      enableTracking: false, // 추적 불필요하므로 비활성화
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isDetecting = false;
  List<Face> _faces = [];
  List<CameraDescription> cameras = [];
  int _selectedCameraIndex = 0;
  bool _permissionGranted = false;
  bool _permissionRequested = false;

  // 이마 사각형 관련 상태 변수
  ForeheadRectangle? _currentForeheadRectangle;

  // 녹화 관련 상태 변수들 (flutter_screen_recording용)
  bool _isRecording = false;
  bool _isProcessing = false;
  String _statusText = '녹화 준비됨';

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndInitialize();

    // 위젯 트리 빌드 완료 후 랭킹 게임 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRankingGame();
    });
  }

  // 랭킹 게임 초기화
  void _initializeRankingGame() async {
    print('🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮');
    print('🎮🔥 랭킹 게임 초기화 시작');
    print('🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮');

    // 현재 선택된 필터 정보 가져오기
    final selectedFilter = ref.read(selectedFilterProvider);

    if (selectedFilter != null) {
      print('🎮✅ 선택된 필터: ${selectedFilter.id} (${selectedFilter.name})');

      // 선택된 필터의 캐릭터 데이터 로드
      final characters =
          await RankingDataService.getCharactersByGameId(selectedFilter.id);

      if (characters.isNotEmpty) {
        print('🎮🎯 캐릭터 로드 성공: ${characters.length}개');
        ref
            .read(rankingGameProvider.notifier)
            .startGame(selectedFilter.id, characters);
      } else {
        print('🎮⚠️ 캐릭터 데이터가 없음, 기본값 사용');
        // 기본값으로 폴백
        final defaultCharacters =
            await RankingDataService.getKpopDemonHuntersCharacters();
        ref
            .read(rankingGameProvider.notifier)
            .startGame('all_characters', defaultCharacters);
      }
    } else {
      print('🎮❌ 선택된 필터가 없음, 기본값 사용');
      // 선택된 필터가 없으면 기본값 사용
      final defaultCharacters =
          await RankingDataService.getKpopDemonHuntersCharacters();
      ref
          .read(rankingGameProvider.notifier)
          .startGame('all_characters', defaultCharacters);
    }

    print('🎮🎉 랭킹 게임 초기화 완료');
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();

    // 이마 이미지 리소스 정리
    ForeheadRectangleService.disposeTextureImage();

    super.dispose();
  }

  Future<void> _requestPermissionsAndInitialize() async {
    try {
      setState(() {
        _permissionRequested = true;
      });

      final status = await Permission.camera.request();
      if (status == PermissionStatus.granted) {
        print("Camera permission granted, initializing cameras...");
        setState(() {
          _permissionGranted = true;
        });
        await _initializeCameras();
      } else {
        print("Camera permission denied");
        if (mounted) {
          setState(() {
            _permissionGranted = false;
          });
        }
      }
    } catch (e) {
      print("Permission request error: $e");
      if (mounted) {
        setState(() {
          _permissionGranted = false;
        });
      }
    }
  }

  // 녹화용 권한 확인 및 요청
  Future<bool> _checkPermissions() async {
    try {
      // 마이크 권한 확인 (flutter_screen_recording에서 필요)
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('마이크 권한이 필요합니다')),
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('권한 확인 오류: $e')),
        );
      }
      return false;
    }
  }

  Future<void> _initializeCameras() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('No Cameras Found');
        return;
      }

      _selectedCameraIndex = cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      if (_selectedCameraIndex == -1) {
        _selectedCameraIndex = 0;
      }

      await _initializeCamera(cameras[_selectedCameraIndex]);
    } catch (e) {
      print(e);
    }
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    final controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup:
          Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );

    _controller = controller;

    _initializeControllerFuture = controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _startFaceDetection();
      });
    }).catchError((error) {
      print(error);
    });
  }

  void _toggleCamera() async {
    if (cameras.isEmpty || cameras.length < 2) {
      print('Can\'t toggle camera. not enough cameras available');
      return;
    }

    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }

    _selectedCameraIndex = (_selectedCameraIndex + 1) % cameras.length;

    setState(() {
      _faces = [];
      _currentForeheadRectangle = null;
    });

    await _initializeCamera(cameras[_selectedCameraIndex]);
  }

  void _startFaceDetection() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    _controller!.startImageStream((CameraImage image) async {
      if (_isDetecting) return;

      _isDetecting = true;

      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      try {
        final List<Face> faces = await _faceDetector.processImage(inputImage);

        // 이마 사각형 계산 (첫 번째 얼굴에 대해서만)
        ForeheadRectangle? foreheadRectangle;
        if (faces.isNotEmpty) {
          final firstFace = faces.first;

          // 현재 선택된 랭킹 아이템의 이미지 경로 가져오기 (단순화)
          final currentRankingItem = ref.read(currentRankingItemProvider);
          final selectedFilter = ref.read(selectedFilterProvider);
          String? imagePath;

          if (currentRankingItem?.assetKey != null && selectedFilter != null) {
            // 이미지 경로 Provider를 통한 단순화된 경로 계산
            final imagePathProvider = ref.read(getImagePathProvider);
            final pathResult = await imagePathProvider(
                selectedFilter.id, currentRankingItem!.assetKey!);
            imagePath = pathResult.path ?? currentRankingItem.imagePath;
          } else {
            // Fallback: 기본 이미지 경로 사용
            imagePath = currentRankingItem?.imagePath;
          }

          foreheadRectangle =
              await ForeheadRectangleService.calculateForeheadRectangle(
            firstFace,
            _controller!,
            imagePath: imagePath,
          );
        }

        if (mounted) {
          setState(() {
            _faces = faces;
            _currentForeheadRectangle = foreheadRectangle;
          });
        }
      } catch (e) {
        print(e);
      } finally {
        _isDetecting = false;
      }
    });
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    if (_controller == null) return null;

    try {
      final format =
          Platform.isIOS ? InputImageFormat.bgra8888 : InputImageFormat.nv21;

      final inputImageMetadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.values.firstWhere(
          (element) =>
              element.rawValue == _controller!.description.sensorOrientation,
          orElse: () => InputImageRotation.rotation0deg,
        ),
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      final bytes = _concatenatePlanes(image.planes);
      return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
    } catch (e) {
      print(e);
      return null;
    }
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }

    return allBytes.done().buffer.asUint8List();
  }

  // 녹화 시작 (flutter_screen_recording 사용)
  Future<void> _startRecording() async {
    // 권한 확인
    if (!await _checkPermissions()) return;

    setState(() {
      _isRecording = true;
      _statusText = '녹화 중...';
    });

    try {
      // flutter_screen_recording으로 화면+오디오 녹화 시작
      bool started = await FlutterScreenRecording.startRecordScreenAndAudio(
        "FilterPlay_Recording_${DateTime.now().millisecondsSinceEpoch}",
        titleNotification: "FilterPlay",
        messageNotification: "화면 녹화 중...",
      );

      if (!started) {
        setState(() {
          _isRecording = false;
          _statusText = '녹화 시작 실패';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('화면 녹화를 시작할 수 없습니다')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _statusText = '녹화 시작 실패: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('녹화 시작 오류: $e')),
        );
      }
    }
  }

  // 녹화 중지 (flutter_screen_recording 사용)
  Future<void> _stopRecording() async {
    setState(() {
      _isRecording = false;
      _isProcessing = true;
      _statusText = '녹화 완료 중...';
    });

    try {
      // flutter_screen_recording으로 녹화 중지 및 파일 경로 받기
      String videoPath = await FlutterScreenRecording.stopRecordScreen;

      setState(() {
        _isProcessing = false;
        _statusText = '녹화 완료!';
      });

      if (mounted && videoPath.isNotEmpty) {
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('동영상이 저장되었습니다'),
            duration: Duration(seconds: 2),
          ),
        );

        // 잠시 대기 후 결과 화면으로 이동
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ResultScreen(
                score: 0, // 임시 점수
                totalBalloons: 0, // 임시 값
                videoPath: videoPath,
              ),
            ),
          );
        }
      } else {
        setState(() {
          _statusText = '녹화된 동영상을 찾을 수 없습니다';
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusText = '녹화 중지 실패: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('녹화 중지 오류: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ranking Filter"),
        actions: [
          if (cameras.length > 1)
            IconButton(
              onPressed: _toggleCamera,
              icon: const Icon(CupertinoIcons.switch_camera_solid),
              color: Colors.blueAccent,
            ),
        ],
      ),
      body: _initializeControllerFuture == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _permissionRequested
                        ? (_permissionGranted
                            ? Icons.camera_alt
                            : Icons.camera_alt_outlined)
                        : Icons.camera_alt_outlined,
                    size: 64,
                    color: _permissionGranted ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _permissionRequested
                        ? (_permissionGranted
                            ? "카메라 초기화 중..."
                            : "카메라 권한이 필요합니다")
                        : "카메라 권한 요청 중...",
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (_permissionRequested && !_permissionGranted) ...const [
                    SizedBox(height: 8),
                    Text(
                      "설정에서 카메라 권한을 허용해주세요",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            )
          : FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    _controller != null &&
                    _controller!.value.isInitialized) {
                  return RepaintBoundary(
                    key: _captureKey,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_controller!),
                        // 이마 이미지 오버레이 (얼굴이 감지되고 이마 사각형이 있을 때만)
                        if (_currentForeheadRectangle != null &&
                            _currentForeheadRectangle!.isValid)
                          CustomPaint(
                            painter: ForeheadImagePainter(
                              foreheadRectangle: _currentForeheadRectangle!,
                              imageSize: Size(
                                _controller!.value.previewSize!.height,
                                _controller!.value.previewSize!.width,
                              ),
                              screenSize: Size(
                                MediaQuery.of(context).size.width,
                                MediaQuery.of(context).size.height,
                              ),
                              currentItemName:
                                  ref.watch(currentRankingItemProvider)?.name ??
                                      "",
                            ),
                          ),
                        // 랭킹 슬롯 패널 (왼쪽)
                        const Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: RankingSlotPanel(),
                        ),
                        // 녹화 상태 표시
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            color: _isRecording
                                ? Colors.red.withValues(alpha: 0.1)
                                : _isProcessing
                                    ? Colors.orange.withValues(alpha: 0.1)
                                    : Colors.green.withValues(alpha: 0.1),
                            child: Row(
                              children: [
                                if (_isRecording)
                                  const Icon(Icons.fiber_manual_record,
                                      color: Colors.red, size: 16),
                                if (_isProcessing)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                if (!_isRecording && !_isProcessing)
                                  const Icon(Icons.check_circle,
                                      color: Colors.green, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _statusText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          offset: Offset(1, 1),
                                          blurRadius: 2,
                                          color: Colors.black54,
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (snapshot.hasError) {
                  return const Center(child: Text('Error'));
                } else {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.blueAccent,
                    ),
                  );
                }
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isProcessing
            ? null
            : _isRecording
                ? _stopRecording
                : _startRecording,
        tooltip: _isRecording ? '녹화 중지' : '녹화 시작',
        backgroundColor: _isRecording
            ? Colors.red
            : _isProcessing
                ? Colors.grey
                : Colors.green,
        child: Icon(_isRecording
            ? Icons.stop
            : _isProcessing
                ? Icons.hourglass_empty
                : Icons.videocam),
      ),
    );
  }
}

/// 이마 영역에 이미지를 표시하는 전용 CustomPainter
class ForeheadImagePainter extends CustomPainter {
  final ForeheadRectangle foreheadRectangle;
  final Size imageSize;
  final Size screenSize;
  final String currentItemName;

  ForeheadImagePainter({
    super.repaint,
    required this.foreheadRectangle,
    required this.imageSize,
    required this.screenSize,
    required this.currentItemName,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 이마 사각형이 유효하지 않으면 아무것도 그리지 않음
    if (!foreheadRectangle.isValid) return;

    // 화면과 이미지 크기 비율 계산
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    final rect = foreheadRectangle;

    // 화면 좌표로 변환된 중심점
    final centerX = rect.center.x * scaleX;
    final centerY = rect.center.y * scaleY;

    // 스케일이 적용된 사각형 크기
    final scaledWidth = rect.width * rect.scale * scaleX;
    final scaledHeight = rect.height * rect.scale * scaleY;

    // Canvas 저장
    canvas.save();

    // 중심점으로 이동
    canvas.translate(centerX, centerY);

    // Z축 회전 (기울기) 적용 - 방향 반전으로 얼굴 기울기와 일치
    canvas.rotate(-rect.rotationZ * pi / 180);

    // Y축 회전을 원근감으로 표현 (스케일 변형)
    final perspectiveScale = cos(rect.rotationY * pi / 180).abs();
    final skewX = sin(rect.rotationY * pi / 180) * 0.3;

    // 변형 행렬 적용 (원근감)
    final transform = Matrix4.identity()
      ..setEntry(0, 0, perspectiveScale) // X축 스케일
      ..setEntry(0, 1, skewX); // X축 기울기 (원근감)

    canvas.transform(transform.storage);

    // 사각형 그리기 (중심 기준)
    final drawRect = Rect.fromCenter(
      center: Offset.zero,
      width: scaledWidth,
      height: scaledHeight,
    );

    // 이미지가 있으면 이미지로 그리기
    if (rect.textureImage != null) {
      final srcRect = Rect.fromLTWH(0, 0, rect.textureImage!.width.toDouble(),
          rect.textureImage!.height.toDouble());

      // 자연스러운 이미지 표시
      final imagePaint = Paint()
        ..color = Colors.white.withValues(alpha: 1.0)
        ..filterQuality = FilterQuality.high;

      canvas.drawImageRect(rect.textureImage!, srcRect, drawRect, imagePaint);
    } else {
      // 이미지가 없는 경우 기본 사각형 (디버그용)
      final rectPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.white.withValues(alpha: 0.8);

      canvas.drawRect(drawRect, rectPaint);

      // 내부 채우기
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: 0.2);
      canvas.drawRect(drawRect, fillPaint);
    }

    // 텍스트 오버레이 그리기
    final textSpan = TextSpan(
      text: currentItemName,
      style: TextStyle(
        color: Colors.white,
        fontSize: scaledHeight * 0.15, // 사각형 높이의 15%
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(
            offset: Offset(1, 1),
            blurRadius: 2,
            color: Colors.black,
          ),
        ],
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // 텍스트를 사각형 하단에 위치
    final textOffset = Offset(
      -textPainter.width / 2,
      scaledHeight / 2 - textPainter.height - 4, // 하단에서 4px 위
    );

    textPainter.paint(canvas, textOffset);

    // Canvas 복원
    canvas.restore();
  }

  @override
  bool shouldRepaint(ForeheadImagePainter oldDelegate) {
    return oldDelegate.foreheadRectangle != foreheadRectangle ||
        oldDelegate.currentItemName != currentItemName;
  }
}
