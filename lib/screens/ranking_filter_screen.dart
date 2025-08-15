import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/forehead_rectangle_service.dart';

/// RankingFilterScreen is a ranking filter page.
class RankingFilterScreen extends StatefulWidget {
  /// Default Constructor
  const RankingFilterScreen({super.key});

  @override
  State<RankingFilterScreen> createState() => _RankingFilterScreenState();
}

class _RankingFilterScreenState extends State<RankingFilterScreen> {
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
  
  // 테스트용 고정 이미지 경로
  static const String _testImagePath = 'assets/images/ranking/kpop_demon_hunters/abby.png';

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initializeCameras();
  }

  @override
  void dispose() {
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
          foreheadRectangle = await ForeheadRectangleService.calculateForeheadRectangle(
            firstFace,
            _controller!,
            imagePath: _testImagePath,
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
                  return Stack(
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
                    ],
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