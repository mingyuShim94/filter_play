import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:record/record.dart';
import '../services/forehead_rectangle_service.dart';
import '../providers/ranking_game_provider.dart';
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

  // 이마 사각형 관련 상태 변수
  ForeheadRectangle? _currentForeheadRectangle;

  // 녹화 관련 상태 변수들
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isConverting = false; // RawRGBA → PNG 변환 상태
  String _statusText = '녹화 준비됨';
  Timer? _frameCaptureTimer;
  final AudioRecorder _audioRecorder = AudioRecorder();
  Directory? _sessionDirectory;
  int _frameCount = 0;
  int _convertedFrames = 0; // 변환 완료된 프레임 수

  // 진단용 타이밍 정보
  DateTime? _recordingStartTime;
  DateTime? _recordingEndTime;
  int _skippedFrames = 0;
  bool _isCapturingFrame = false;

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
    ref
        .read(rankingGameProvider.notifier)
        .startGame('kpop_demon_hunters', characters);
  }

  @override
  void dispose() {
    // 타이머 및 캡처 상태 확실히 정리
    _frameCaptureTimer?.cancel();
    _frameCaptureTimer = null;
    _isCapturingFrame = false;
    _isRecording = false;
    _isConverting = false;

    _controller?.dispose();
    _faceDetector.close();
    _audioRecorder.dispose();

    // 이마 이미지 리소스 정리
    ForeheadRectangleService.disposeTextureImage();

    // 테스트를 위해 세션 디렉토리 보존 (삭제하지 않음)
    // if (_sessionDirectory != null && _sessionDirectory!.existsSync()) {
    //   _sessionDirectory!.delete(recursive: true).catchError((e) {
    //     print('세션 디렉토리 삭제 오류: $e');
    //     return _sessionDirectory!; // 에러 시 원본 디렉토리 반환
    //   });
    // }

    super.dispose();
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      print("Permissions Denied");
    }
  }

  // 녹화용 권한 확인 및 요청
  Future<bool> _checkPermissions() async {
    try {
      // 마이크 권한 확인
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

          // 현재 선택된 랭킹 아이템의 이미지 경로 가져오기
          final currentRankingItem = ref.read(currentRankingItemProvider);
          final imagePath = currentRankingItem?.imagePath;

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
    // 권한 확인
    if (!await _checkPermissions()) return;

    setState(() {
      _isRecording = true;
      _statusText = '녹화 중...';
      _frameCount = 0;
      _skippedFrames = 0;
      _isCapturingFrame = false;
      _recordingStartTime = DateTime.now();
    });

    try {
      // 임시 세션 디렉토리 생성
      final tempDir = await getTemporaryDirectory();
      _sessionDirectory = Directory(
        '${tempDir.path}/record_${DateTime.now().millisecondsSinceEpoch}',
      );
      await _sessionDirectory!.create();

      // 오디오 녹음 시작
      final audioPath = '${_sessionDirectory!.path}/audio.m4a';
      await _audioRecorder.start(const RecordConfig(), path: audioPath);

      // 적응형 프레임 캡처 (성능에 따라 조정)
      _frameCaptureTimer = Timer.periodic(
        Duration(
            microseconds: (1000000 / 20).round()), // 20fps로 안정성 우선 (50ms 간격)
        (timer) => _captureFrameForRecording(),
      );
    } catch (e) {
      setState(() {
        _isRecording = false;
        _statusText = '녹화 시작 실패: $e';
      });
    }
  }

  // 재귀 타이밍 시스템 - 캡처 완료 후 다음 캡처 예약
  void _scheduleNextCapture() {
    if (!_isRecording || !mounted) return;

    // 50ms 후 다음 캡처 예약 (20fps)
    Timer(const Duration(milliseconds: 50), () async {
      if (_isRecording && mounted) {
        await _captureFrameForRecording();
        _scheduleNextCapture(); // 캡처 완료 후 다음 예약
      }
    });
  }

  // 녹화용 프레임 캡처 (연속)
  Future<void> _captureFrameForRecording() async {
    // 위젯이 dispose된 상태에서는 실행하지 않음
    if (!mounted) return;

    // 이전 캡처가 진행 중이면 스킵
    if (_isCapturingFrame) {
      _skippedFrames++;
      print('\x1b[91m🎬 ⏭️  프레임 스킵됨 (캡처 진행 중): $_skippedFrames\x1b[0m');
      return;
    }

    _isCapturingFrame = true;
    final captureStartTime = DateTime.now();

    try {
      RenderRepaintBoundary boundary = _captureKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      // 해상도 정보 사전 수집 (async 작업 전)
      final screenSize = MediaQuery.of(context).size;
      final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      final logicalWidth = screenSize.width.round();
      final logicalHeight = screenSize.height.round();

      // RawRGBA 고해상도 캡처: devicePixelRatio 적용으로 물리적 픽셀 해상도 사용
      ui.Image image = await boundary.toImage(pixelRatio: devicePixelRatio);

      // RawRGBA 포맷으로 변환 (압축 없음, 고속 처리)
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);

      if (byteData != null) {
        Uint8List rawBytes = byteData.buffer.asUint8List();

        // 해상도 분석 및 로깅
        final width = image.width;
        final height = image.height;
        final resolutionGain = (width * height) / (logicalWidth * logicalHeight);
        
        print('\x1b[96m📱 해상도 분석:\x1b[0m');
        print('\x1b[96m  • 논리적 해상도: ${logicalWidth}x$logicalHeight\x1b[0m');
        print('\x1b[96m  • Device Pixel Ratio: $devicePixelRatio\x1b[0m');
        print('\x1b[96m  • 캡처된 해상도: ${width}x$height\x1b[0m');
        print('\x1b[96m  • 해상도 향상: ${resolutionGain.toStringAsFixed(1)}배\x1b[0m');

        final fileName =
            'frame_${(_frameCount + 1).toString().padLeft(5, '0')}_${width}x$height.raw';
        final file = File('${_sessionDirectory!.path}/$fileName');

        // RawRGBA 데이터 즉시 저장 (비압축이므로 빠름)
        await file.writeAsBytes(rawBytes);

        // setState 호출 전 mounted 체크
        if (mounted) {
          setState(() {
            _frameCount++;
          });
        }

        final captureEndTime = DateTime.now();
        final captureDuration =
            captureEndTime.difference(captureStartTime).inMilliseconds;

        // 메모리 사용량 계산
        final rawDataSize = rawBytes.length;
        final rawDataSizeMB = rawDataSize / (1024 * 1024);

        // 고해상도 성능 측정 로그 (예상 증가: 10-20ms → 30-60ms)
        print('\x1b[95m⚡ 성능 분석:\x1b[0m');
        print('\x1b[95m  • 캡처 시간: ${captureDuration}ms\x1b[0m');
        print('\x1b[95m  • 데이터 크기: ${rawDataSizeMB.toStringAsFixed(1)}MB\x1b[0m');
        
        if (captureDuration > 60) {
          print('\x1b[91m🎬 ⚠️  고해상도 캡처 느림: ${captureDuration}ms\x1b[0m');
        } else if (captureDuration > 30) {
          print('\x1b[93m🎬 ⚡ 고해상도 캡처 보통: ${captureDuration}ms\x1b[0m');
        } else {
          print('\x1b[92m🎬 ✅ 고해상도 캡처 빠름: ${captureDuration}ms\x1b[0m');
        }
      }

      // 이미지 메모리 해제
      image.dispose();
    } catch (e) {
      print('RawRGBA 프레임 캡처 오류: $e');
    } finally {
      _isCapturingFrame = false;
    }
  }

  // 녹화 중지
  Future<void> _stopRecording() async {
    _recordingEndTime = DateTime.now();

    setState(() {
      _isRecording = false;
      _isProcessing = true;
      _statusText = '녹화 완료, RawRGBA 프레임 변환 준비 중...';
    });

    try {
      // 타이머 중지
      _frameCaptureTimer?.cancel();
      _frameCaptureTimer = null;

      // 오디오 녹음 중지
      await _audioRecorder.stop();

      // RawRGBA → PNG 변환 후 FFmpeg 실행
      await _convertRawToPngAndCompose();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusText = '녹화 중지 실패: $e';
      });
    }
  }

  // RawRGBA → PNG 변환 및 동영상 합성
  Future<void> _convertRawToPngAndCompose() async {
    setState(() {
      _isConverting = true;
      _statusText = 'RawRGBA 프레임을 PNG로 변환 중...';
    });

    try {
      // 1단계: RawRGBA → PNG 변환
      await _convertRawFramesToPng();

      // 2단계: PNG로 FFmpeg 동영상 합성
      await _composeVideo();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isConverting = false;
        _statusText = 'RawRGBA 변환 실패: $e';
      });
      rethrow;
    }
  }

  // RawRGBA 프레임들을 PNG로 변환
  Future<void> _convertRawFramesToPng() async {
    try {
      // .raw 파일들 찾기
      final rawFiles = _sessionDirectory!
          .listSync()
          .where((file) => file is File && file.path.endsWith('.raw'))
          .cast<File>()
          .toList();

      rawFiles.sort((a, b) => a.path.compareTo(b.path)); // 파일명 순서로 정렬

      print('\x1b[96m🔄 RawRGBA → PNG 변환 시작: ${rawFiles.length}개 프레임\x1b[0m');

      for (int i = 0; i < rawFiles.length; i++) {
        final rawFile = rawFiles[i];

        // 파일명에서 크기 정보 추출
        final fileName = rawFile.path.split('/').last;
        final match =
            RegExp(r'frame_(\d+)_(\d+)x(\d+)\.raw').firstMatch(fileName);

        if (match == null) {
          print('🔄 ⚠️  파일명 형식 오류: $fileName');
          continue;
        }

        final frameNumber = match.group(1)!;
        final width = int.parse(match.group(2)!);
        final height = int.parse(match.group(3)!);

        // PNG 파일 경로
        final pngFile = File(
            '${_sessionDirectory!.path}/frame_${frameNumber.padLeft(5, '0')}.png');

        // RawRGBA 변환
        await _convertSingleRawToPng(rawFile, width, height, pngFile);

        // 진행률 업데이트
        if (mounted) {
          setState(() {
            _convertedFrames = i + 1;
            _statusText = 'PNG 변환 중... ${i + 1}/${rawFiles.length}';
          });
        }
      }

      print('\x1b[92m🔄 ✅ RawRGBA → PNG 변환 완료: ${rawFiles.length}개 프레임\x1b[0m');

      // 테스트를 위해 .raw 파일들 보존 (삭제하지 않음)
      print('🔄 💾 .raw 파일들 보존됨 (테스트용)');
    } catch (e) {
      print('🔄 ❌ RawRGBA 변환 오류: $e');
      rethrow;
    }
  }

  // 단일 RawRGBA 파일을 PNG로 변환 (강화된 검증)
  Future<void> _convertSingleRawToPng(
      File rawFile, int width, int height, File pngFile) async {
    try {
      final rawBytes = await rawFile.readAsBytes();
      
      // 1. 데이터 크기 검증 (RGBA = 4바이트/픽셀)
      final expectedSize = width * height * 4;
      if (rawBytes.length != expectedSize) {
        throw Exception('데이터 크기 불일치: 예상 ${expectedSize}B, 실제 ${rawBytes.length}B');
      }

      // 2. 기본 데이터 무결성 검증
      if (rawBytes.isEmpty || width <= 0 || height <= 0) {
        throw Exception('유효하지 않은 이미지 데이터: ${width}x${height}, ${rawBytes.length}B');
      }

      // 3. RawRGBA 데이터를 직접 ui.Image로 변환
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        rawBytes,
        width,
        height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      final image = await completer.future;

      // 4. ui.Image → PNG 변환
      final pngByteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (pngByteData == null) {
        image.dispose();
        throw Exception('PNG 데이터 생성 실패');
      }

      // 5. PNG 파일 쓰기
      final pngBytes = pngByteData.buffer.asUint8List();
      await pngFile.writeAsBytes(pngBytes);
        
      // 6. PNG 파일 유효성 검증
      await _validatePngFile(pngFile, width, height);
        
      print('🔄 ✅ 변환 성공: ${width}x${height} -> ${await pngFile.length()}B PNG');

      // 7. 메모리 정리 (중요: 누수 방지)
      image.dispose();
    } catch (e) {
      print('🔄 ❌ 단일 프레임 변환 실패: ${rawFile.path} -> ${pngFile.path}');
      print('🔄 ❌ 오류 상세: $e');

      // 변환 실패 시 대안 방법 시도
      await _fallbackToPngCapture(pngFile, width, height);
    }
  }

  // PNG 파일 유효성 검증
  Future<void> _validatePngFile(File pngFile, int width, int height) async {
    final fileExists = await pngFile.exists();
    if (!fileExists) {
      throw Exception('PNG 파일이 생성되지 않음');
    }

    final fileSize = await pngFile.length();
    
    // 최소 크기 검증 (PNG 헤더 + 최소 데이터)
    if (fileSize < 100) {
      throw Exception('PNG 파일이 너무 작음: ${fileSize}B (최소 100B 필요)');
    }

    // PNG 시그니처 검증
    final bytes = await pngFile.readAsBytes();
    if (bytes.length < 8) {
      throw Exception('PNG 파일 헤더가 불완전함');
    }

    // PNG 매직 넘버 확인 (0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A)
    final pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    for (int i = 0; i < 8; i++) {
      if (bytes[i] != pngSignature[i]) {
        throw Exception('PNG 시그니처 불일치: 유효하지 않은 PNG 파일');
      }
    }

    // 합리적인 최대 크기 검증 (과도하게 큰 파일 방지)
    final maxExpectedSize = width * height * 4 + 1024; // RGBA + 헤더 여유분
    if (fileSize > maxExpectedSize) {
      print('🔄 ⚠️  PNG 파일이 예상보다 큼: ${fileSize}B (최대 예상: ${maxExpectedSize}B)');
    }

    print('🔄 🔍 PNG 검증 통과: ${fileSize}B, 시그니처 OK');
  }
  
  // 변환 실패 시 강화된 대안 방법
  Future<void> _fallbackToPngCapture(File pngFile, int width, int height) async {
    try {
      print('🔄 ⚠️  대안 방법: 강화된 PNG 직접 캡처 시도');
      
      // 1. RepaintBoundary 상태 검증
      if (_captureKey.currentContext == null) {
        throw Exception('대안 캡처 실패: RepaintBoundary context가 null');
      }

      RenderRepaintBoundary? boundary = _captureKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary == null) {
        throw Exception('대안 캡처 실패: RenderRepaintBoundary를 찾을 수 없음');
      }

      // 2. 고해상도 캡처를 위해 devicePixelRatio 사용 (context 보존)
      if (!mounted) return;
      final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

      // 3. 이미지 캡처 (고해상도)
      final clampedPixelRatio = devicePixelRatio;
      ui.Image image = await boundary.toImage(pixelRatio: clampedPixelRatio);
      
      // 4. PNG 인코딩
      final pngByteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (pngByteData == null) {
        image.dispose();
        throw Exception('대안 PNG 데이터 생성 실패');
      }

      // 5. 파일 쓰기 및 검증
      final pngBytes = pngByteData.buffer.asUint8List();
      await pngFile.writeAsBytes(pngBytes);
      
      // 6. 대안 방법으로 생성된 파일 검증
      await _validatePngFile(pngFile, image.width, image.height);
        
      print('🔄 ✅ 대안 캡처 성공: ${image.width}x${image.height} -> ${pngBytes.length}B (계수 pixelRatio: $clampedPixelRatio)');
      
      // 7. 메모리 정리
      image.dispose();
    } catch (e) {
      print('🔄 ❌ 대안 방법도 실패: $e');
      
      // 최종 대체: 빈 PNG 파일 생성 (전체 실패 방지)
      await _createEmptyPngFile(pngFile, width, height);
    }
  }

  // 최종 대체: 빈 PNG 파일 생성
  Future<void> _createEmptyPngFile(File pngFile, int width, int height) async {
    try {
      print('🔄 🌆 최종 대안: 빈 PNG 파일 생성');
      
      // 1x1 크기의 기본 PNG 데이터 (투명 픽셀)
      final emptyPngBytes = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG 시그니처
        0x00, 0x00, 0x00, 0x0D, // IHDR 청크 사이즈
        0x49, 0x48, 0x44, 0x52, // IHDR 청크 타입
        0x00, 0x00, 0x00, 0x01, // 넓이: 1
        0x00, 0x00, 0x00, 0x01, // 높이: 1
        0x08, 0x06, 0x00, 0x00, 0x00, // bit depth=8, color type=6 (RGBA)
        0x1F, 0x15, 0xC4, 0x89, // IHDR CRC
        0x00, 0x00, 0x00, 0x0A, // IDAT 청크 사이즈
        0x49, 0x44, 0x41, 0x54, // IDAT 청크 타입
        0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, // 압축된 데이터
        0x0D, 0x0A, 0x2D, 0xB4, // IDAT CRC
        0x00, 0x00, 0x00, 0x00, // IEND 청크 사이즈
        0x49, 0x45, 0x4E, 0x44, // IEND 청크 타입
        0xAE, 0x42, 0x60, 0x82  // IEND CRC
      ];
      
      await pngFile.writeAsBytes(emptyPngBytes);
      print('🔄 ✅ 빈 PNG 파일 생성 완료: ${emptyPngBytes.length}B');
    } catch (e) {
      print('🔄 ❌ 빈 PNG 파일 생성도 실패: $e');
      // 이 경우에도 예외를 던지지 않고 계속 진행
    }
  }

  // FFmpeg를 사용한 동영상 합성
  Future<void> _composeVideo() async {
    try {
      // 실제 FPS 계산 및 녹화 통계 출력
      double actualFps = 24.0; // 기본값
      if (_recordingStartTime != null && _recordingEndTime != null) {
        final actualRecordingDuration =
            _recordingEndTime!.difference(_recordingStartTime!);
        final actualRecordingSeconds =
            actualRecordingDuration.inMilliseconds / 1000.0;
        actualFps = _frameCount / actualRecordingSeconds;
        final expectedFrames =
            (actualRecordingDuration.inMilliseconds / (1000 / 20))
                .round(); // 20fps 기준

        print(
            '\x1b[96m🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬\x1b[0m');
        print(
            '\x1b[93m🎬🎬🎬🎬🎬🎬🎬🎬🎬 📊 녹화 시간 분석 📊 🎬🎬🎬🎬🎬🎬🎬🎬🎬\x1b[0m');
        print(
            '\x1b[96m🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬\x1b[0m');
        print(
            '\x1b[92m🎬 ⏱️  실제 녹화 시간: ${actualRecordingDuration.inSeconds}.${actualRecordingDuration.inMilliseconds % 1000}초\x1b[0m');
        print('\x1b[92m🎬 📹 캡처된 프레임 수: $_frameCount\x1b[0m');
        print('\x1b[92m🎬 🎯 예상 프레임 수: $expectedFrames (20fps 기준)\x1b[0m');
        print(
            '\x1b[94m🎬 📊 실제 캡처 FPS: ${actualFps.toStringAsFixed(2)}\x1b[0m');
        print('\x1b[91m🎬 ⚠️  스킵된 프레임 수: $_skippedFrames\x1b[0m');
        print(
            '\x1b[91m🎬 📉 프레임 손실률: ${((_skippedFrames / (expectedFrames > 0 ? expectedFrames : 1)) * 100).toStringAsFixed(1)}%\x1b[0m');
        print(
            '\x1b[96m🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬\x1b[0m');
      }

      // 출력 파일 경로
      final documentsDir = await getApplicationDocumentsDirectory();
      final outputPath =
          '${documentsDir.path}/screen_record_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // FFmpeg 명령어 구성 (PNG 파일 사용)
      final framePath = '${_sessionDirectory!.path}/frame_%05d.png';
      final audioPath = '${_sessionDirectory!.path}/audio.m4a';

      // 파일 존재 여부 확인
      final audioFile = File(audioPath);
      final firstFrameFile = File('${_sessionDirectory!.path}/frame_00001.png');

      // 동적 프레임레이트로 정확한 동영상 길이 계산
      final expectedDurationSeconds = _frameCount / actualFps;

      String command;

      if (audioFile.existsSync() && audioFile.lengthSync() > 0) {
        // 오디오와 비디오 함께 합성 - 실제 fps로 정확한 동기화
        command =
            '-framerate ${actualFps.toStringAsFixed(2)} -i "$framePath" -i "$audioPath" -vf "scale=360:696" -c:v libx264 -c:a aac -pix_fmt yuv420p -preset ultrafast "$outputPath"';
        print(
            '\x1b[95m🎬 🎵 오디오+비디오 합성 모드 (실제fps: ${actualFps.toStringAsFixed(2)}, 예상길이: ${expectedDurationSeconds.toStringAsFixed(1)}초)\x1b[0m');
      } else {
        // 비디오만 생성
        command =
            '-framerate ${actualFps.toStringAsFixed(2)} -i "$framePath" -vf "scale=360:696" -c:v libx264 -pix_fmt yuv420p -preset ultrafast "$outputPath"';
        print(
            '\x1b[94m🎬 📹 비디오 전용 합성 모드 (실제fps: ${actualFps.toStringAsFixed(2)}, 예상길이: ${expectedDurationSeconds.toStringAsFixed(1)}초)\x1b[0m');
      }

      print(
          '\x1b[95m🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬\x1b[0m');
      print(
          '\x1b[93m🎬🎬🎬🎬🎬🎬 ⚙️  FFmpeg 동영상 합성 시작 ⚙️  🎬🎬🎬🎬🎬🎬\x1b[0m');
      print(
          '\x1b[95m🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬\x1b[0m');
      print('🎬 명령어: $command');
      print('🎬 프레임 경로: $framePath');
      print('🎬 오디오 경로: $audioPath');
      print('🎬 출력 경로: $outputPath');

      // 파일 존재 여부 및 상세 정보 확인

      print('🎬 오디오 파일 존재: ${audioFile.existsSync()}');
      if (audioFile.existsSync()) {
        print('🎬 오디오 파일 크기: ${audioFile.lengthSync()} bytes');
      }

      print('🎬 첫 번째 프레임 존재: ${firstFrameFile.existsSync()}');
      if (firstFrameFile.existsSync()) {
        print('🎬 첫 번째 프레임 크기: ${firstFrameFile.lengthSync()} bytes');
      }

      print('🎬 프레임 개수: $_frameCount');
      print('🎬 세션 디렉토리: ${_sessionDirectory!.path}');

      // 디렉토리 내 실제 프레임 파일 수 확인
      try {
        final files = _sessionDirectory!.listSync();
        final frameFiles = files
            .where((file) =>
                file is File &&
                file.path.contains('frame_') &&
                file.path.endsWith('.png'))
            .toList();

        print('🎬 디렉토리 내 전체 파일 개수: ${files.length}');
        print('🎬 실제 프레임 파일 개수: ${frameFiles.length}');
        print('🎬 카운터 프레임 개수: $_frameCount');
        print(
            '🎬 프레임 파일 불일치: ${frameFiles.length != _frameCount ? "있음" : "없음"}');

        for (final file in files.take(3)) {
          // 처음 3개만 출력
          if (file is File) {
            print(
                '🎬 파일: ${file.path.split('/').last} (${file.lengthSync()} bytes)');
          }
        }

        // 실제 프레임 파일 수로 재계산
        if (frameFiles.length != _frameCount) {
          print('🎬 ⚠️ 프레임 카운터와 실제 파일 수가 다릅니다!');
          print('🎬 실제 저장된 프레임으로 길이 재계산: ${frameFiles.length / 24.0}초');
        }
      } catch (e) {
        print('🎬 디렉토리 읽기 오류: $e');
      }
      print('🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬');

      // FFmpeg 실행 (타임아웃 30초)
      print('\x1b[94m🎬 ⚡ FFmpeg 실행 시작...\x1b[0m');

      dynamic session;
      try {
        session = await FFmpegKit.execute(command).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('\x1b[91m❌ FFmpeg 30초 타임아웃!\x1b[0m');
            throw TimeoutException(
                'FFmpeg 실행 타임아웃', const Duration(seconds: 30));
          },
        );
        print('\x1b[92m🎬 ✅ FFmpeg 실행 완료!\x1b[0m');
      } catch (e) {
        if (e is TimeoutException) {
          print('❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌');
          print('❌ FFmpeg 타임아웃! (30초 초과)');
          print('❌ 더 간단한 명령어나 더 적은 프레임으로 시도해보세요');
          print('❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌');
        } else {
          print('❌ FFmpeg 실행 중 오류: $e');
        }
        rethrow;
      }

      final returnCode = await session.getReturnCode();
      final output = await session.getOutput();
      final failStackTrace = await session.getFailStackTrace();
      final logs = await session.getAllLogs();

      print('🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬');
      print('🎬 FFmpeg 실행 결과');
      print('🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬');
      print('🎬 리턴 코드: $returnCode');
      print('🎬 FFmpeg 출력 (길이: ${output?.length ?? 0}):');
      if (output != null && output.isNotEmpty) {
        // 출력을 작은 청크로 나누어 출력
        final chunks = _splitStringIntoChunks(output, 1000);
        for (int i = 0; i < chunks.length; i++) {
          print('🎬 출력[$i/${chunks.length - 1}]: ${chunks[i]}');
        }
      } else {
        print('🎬 출력이 비어있음');
      }

      if (failStackTrace != null && failStackTrace.isNotEmpty) {
        print('🎬 에러 스택: $failStackTrace');
      } else {
        print('🎬 에러 스택이 비어있음');
      }

      // 로그 출력
      if (logs.isNotEmpty) {
        print('🎬 전체 로그 개수: ${logs.length}');
        for (int i = 0; i < logs.length && i < 10; i++) {
          // 최대 10개만
          final log = logs[i];
          print('🎬 로그[$i]: ${log.getMessage()}');
        }
      } else {
        print('🎬 로그가 비어있음');
      }
      print('🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬');

      if (ReturnCode.isSuccess(returnCode)) {
        // 성공적으로 완료 (테스트를 위해 임시 파일 보존)
        // await _cleanupTempFiles(); // 테스트를 위해 주석 처리
        setState(() {
          _isProcessing = false;
          _isConverting = false;
          _statusText = '녹화 완료! 저장됨: ${outputPath.split('/').last}';
        });

        print(
            '\x1b[92m🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬\x1b[0m');
        print('\x1b[93m🎬🎬🎬🎬🎬 🎉 동영상 합성 성공! 🎉 🎬🎬🎬🎬🎬\x1b[0m');
        print(
            '\x1b[92m🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬🎬\x1b[0m');
        print('\x1b[96m🎬 💾 저장된 파일: ${outputPath.split('/').last}\x1b[0m');

        if (mounted) {
          // 성공 메시지 표시
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('동영상이 저장되었습니다: ${outputPath.split('/').last}'),
              duration: const Duration(seconds: 2),
            ),
          );

          // 결과 화면으로 이동 (동영상 경로 전달)
          await Future.delayed(
              const Duration(milliseconds: 500)); // 스낵바 표시 후 잠깐 대기

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => ResultScreen(
                  score: 0, // 임시 점수 (실제 게임 점수로 대체 필요)
                  totalBalloons: 0, // 임시 값 (실제 게임 데이터로 대체 필요)
                  videoPath: outputPath,
                ),
              ),
            );
          }
        }
      } else {
        print('❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌');
        print('❌ FFmpeg 실행 실패!');
        print('❌ 리턴 코드: $returnCode');
        print('❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌');
        throw Exception('FFmpeg 실행 실패 - 리턴 코드: $returnCode');
      }
    } catch (e) {
      print('❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌');
      print('❌ 동영상 합성 치명적 오류!');
      print('❌ 오류 내용: $e');
      print('❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌');
      setState(() {
        _isProcessing = false;
        _statusText = '동영상 합성 실패: $e';
      });
    }
  }

  // 문자열을 청크로 나누는 헬퍼 메서드
  List<String> _splitStringIntoChunks(String input, int chunkSize) {
    List<String> chunks = [];
    for (int i = 0; i < input.length; i += chunkSize) {
      chunks.add(input.substring(
          i, (i + chunkSize < input.length) ? i + chunkSize : input.length));
    }
    return chunks;
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
                                    ? _isConverting
                                        ? Colors.blue.withValues(alpha: 0.1)
                                        : Colors.orange.withValues(alpha: 0.1)
                                    : Colors.green.withValues(alpha: 0.1),
                            child: Row(
                              children: [
                                if (_isRecording)
                                  const Icon(Icons.fiber_manual_record,
                                      color: Colors.red, size: 16),
                                if (_isProcessing)
                                  _isConverting
                                      ? const Icon(Icons.transform,
                                          color: Colors.blue, size: 16)
                                      : const SizedBox(
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
                                if (_isConverting) ...{
                                  Text(
                                    '변환: $_convertedFrames/$_frameCount',
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

    // Canvas 복원
    canvas.restore();
  }

  @override
  bool shouldRepaint(ForeheadImagePainter oldDelegate) {
    return oldDelegate.foreheadRectangle != foreheadRectangle;
  }
}
