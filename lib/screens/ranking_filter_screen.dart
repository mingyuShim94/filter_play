import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../services/forehead_rectangle_service.dart';
import '../providers/ranking_game_provider.dart';
import '../services/ranking_data_service.dart';
import '../widgets/ranking_slot_panel.dart';

/// RankingFilterScreen is a ranking filter page.
class RankingFilterScreen extends ConsumerStatefulWidget {
  /// Default Constructor
  const RankingFilterScreen({super.key});

  @override
  ConsumerState<RankingFilterScreen> createState() => _RankingFilterScreenState();
}

class _RankingFilterScreenState extends ConsumerState<RankingFilterScreen> {
  // RepaintBoundary를 참조하기 위한 GlobalKey
  final GlobalKey _captureKey = GlobalKey();
  
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: false,  // 웃음 확률 등 불필요하므로 비활성화
      enableLandmarks: true,        // 이마 계산에 필요한 눈, 코 랜드마크 활성화
      enableTracking: false,        // 추적 불필요하므로 비활성화
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isDetecting = false;
  List<Face> _faces = [];
  List<CameraDescription> cameras = [];
  int _selectedCameraIndex = 0;
  
  // 이마 사각형 관련 상태 변수
  ForeheadRectangle? _currentForeheadRectangle;
  
  // 녹화 관련 상태 변수들
  bool _isRecording = false;
  bool _isProcessing = false;
  String _statusText = '녹화 준비됨';
  Timer? _frameCaptureTimer;
  Directory? _sessionDirectory;
  int _frameCount = 0;
  

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initializeCameras();
    
    // 위젯 트리 빌드 완료 후 랭킹 게임 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRankingGame();
    });
  }

  // 랭킹 게임 초기화
  void _initializeRankingGame() {
    // K-pop 데몬 헌터스 랭킹 게임 시작
    final characters = RankingDataService.getKpopDemonHuntersCharacters();
    ref.read(rankingGameProvider.notifier).startGame('kpop_demon_hunters', characters);
  }

  @override
  void dispose() {
    // 타이머 확실히 정리
    _frameCaptureTimer?.cancel();
    _frameCaptureTimer = null;
    
    _controller?.dispose();
    _faceDetector.close();
    // 이마 이미지 리소스 정리
    ForeheadRectangleService.disposeTextureImage();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      print("Permissions Denied");
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

    _initializeControllerFuture = controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {
            _startFaceDetection();
          });
        })
        .catchError((error) {
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
          
          // 현재 선택된 랭킹 아이템의 이미지 경로 가져오기
          final currentRankingItem = ref.read(currentRankingItemProvider);
          final imagePath = currentRankingItem?.imagePath;
          
          foreheadRectangle = await ForeheadRectangleService.calculateForeheadRectangle(
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

  // 프레임 캡처 함수 (단일 캡처용)
  Future<void> _captureFrame() async {
    try {
      RenderRepaintBoundary boundary = _captureKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        Uint8List pngBytes = byteData.buffer.asUint8List();

        // 저장할 디렉토리 가져오기
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'capture_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File('${directory.path}/$fileName');

        await file.writeAsBytes(pngBytes);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('화면이 캡처되었습니다: $fileName'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
        print('캡처 완료: ${file.path}');
      }
    } catch (e) {
      print('캡처 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('캡처 실패: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 녹화 시작
  Future<void> _startRecording() async {
    setState(() {
      _isRecording = true;
      _statusText = '녹화 중...';
      _frameCount = 0;
    });

    try {
      // 임시 세션 디렉토리 생성
      final tempDir = await getTemporaryDirectory();
      _sessionDirectory = Directory(
        '${tempDir.path}/record_${DateTime.now().millisecondsSinceEpoch}',
      );
      await _sessionDirectory!.create();

      // 프레임 캡처 시작 (24fps)
      _frameCaptureTimer = Timer.periodic(
        Duration(milliseconds: (1000 / 24).round()),
        (timer) => _captureFrameForRecording(),
      );
    } catch (e) {
      setState(() {
        _isRecording = false;
        _statusText = '녹화 시작 실패: $e';
      });
    }
  }

  // 녹화용 프레임 캡처 (연속)
  Future<void> _captureFrameForRecording() async {
    // 위젯이 dispose된 상태에서는 실행하지 않음
    if (!mounted) return;
    
    try {
      RenderRepaintBoundary boundary = _captureKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        Uint8List pngBytes = byteData.buffer.asUint8List();

        // 파일 이름을 숫자 패딩으로 생성 (FFmpeg에서 중요함)
        final fileName =
            'frame_${(_frameCount + 1).toString().padLeft(5, '0')}.png';
        final file = File('${_sessionDirectory!.path}/$fileName');

        await file.writeAsBytes(pngBytes);

        // setState 호출 전 mounted 체크
        if (mounted) {
          setState(() {
            _frameCount++;
          });
        }
      }
    } catch (e) {
      print('프레임 캡처 오류: $e');
    }
  }

  // 녹화 중지
  Future<void> _stopRecording() async {
    // 타이머 먼저 중지하여 추가 프레임 캡처 방지
    _frameCaptureTimer?.cancel();
    _frameCaptureTimer = null;
    
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isProcessing = true;
        _statusText = '녹화 중지됨 - $_frameCount 프레임 저장됨';
      });
    }

    try {
      // 임시 파일 정리 (2단계에서는 삭제하지 않고 유지)
      // await _cleanupTempFiles();
      
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusText = '녹화 완료 - $_frameCount 프레임';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('녹화 완료: $_frameCount 프레임 저장됨\n경로: ${_sessionDirectory!.path}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusText = '녹화 중지 실패: $e';
        });
      }
    }
  }

  // 임시 파일 정리
  Future<void> _cleanupTempFiles() async {
    try {
      if (_sessionDirectory != null && _sessionDirectory!.existsSync()) {
        await _sessionDirectory!.delete(recursive: true);
      }
    } catch (e) {
      print('임시 파일 정리 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Ranking Filter"),
        actions: [
          if (cameras.length > 1)
            IconButton(
              onPressed: _toggleCamera,
              icon: Icon(CupertinoIcons.switch_camera_solid),
              color: Colors.blueAccent,
            ),
        ],
      ),
      body: _initializeControllerFuture == null
          ? Center(child: Text("No Camera Available"))
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
                      if (_currentForeheadRectangle != null && _currentForeheadRectangle!.isValid)
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                  child: CircularProgressIndicator(strokeWidth: 2),
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
                              if (_isRecording) ...{
                                Text(
                                  '프레임: $_frameCount',
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
                                ),
                              },
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  );
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error'));
                } else {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.blueAccent,
                    ),
                  );
                }
              },
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 단일 캡처 버튼
          FloatingActionButton(
            heroTag: "capture",
            onPressed: _isRecording || _isProcessing ? null : _captureFrame,
            tooltip: '화면 캡처',
            backgroundColor: _isRecording || _isProcessing ? Colors.grey : null,
            child: const Icon(Icons.camera_alt),
          ),
          const SizedBox(height: 12),
          // 녹화 시작/중지 버튼
          FloatingActionButton(
            heroTag: "recording",
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
        ],
      ),
    );
  }
}

/// 이마 영역에 이미지를 표시하는 전용 CustomPainter
class ForeheadImagePainter extends CustomPainter {
  final ForeheadRectangle foreheadRectangle;
  final Size imageSize;
  final Size screenSize;

  ForeheadImagePainter({
    super.repaint,
    required this.foreheadRectangle,
    required this.imageSize,
    required this.screenSize,
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
      final srcRect = Rect.fromLTWH(
        0, 0, 
        rect.textureImage!.width.toDouble(), 
        rect.textureImage!.height.toDouble()
      );
      
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

    // Canvas 복원
    canvas.restore();
  }

  @override
  bool shouldRepaint(ForeheadImagePainter oldDelegate) {
    return oldDelegate.foreheadRectangle != foreheadRectangle;
  }
}