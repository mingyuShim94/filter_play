import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:video_player/video_player.dart';
import '../services/forehead_rectangle_service.dart';
import '../providers/ranking_game_provider.dart';
import '../providers/filter_provider.dart';
import '../providers/image_path_provider.dart';
import '../services/ranking_data_service.dart';
import '../services/video_processing_service.dart';
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

  // 녹화 시간 관련 변수들
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  // 카메라 영역 정보 저장
  double _cameraWidth = 0;
  double _cameraHeight = 0;
  double _leftOffset = 0;
  double _topOffset = 0;
  double _screenWidth = 0;
  double _screenHeight = 0;

  // 크롭 영역 시각화 관련
  bool _showCropArea = false;

  // 비디오 처리 재시도 관련
  int _processingRetryCount = 0;
  static const int _maxProcessingRetries = 3;

  @override
  void initState() {
    super.initState();

    // 기본 시스템 UI 모드 유지 (상태바와 내비게이션 바 표시)
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive); // 주석 처리

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

    // 녹화 타이머 정리
    _recordingTimer?.cancel();

    // 이마 이미지 리소스 정리
    ForeheadRectangleService.disposeTextureImage();

    // 시스템 UI 모드를 기본값으로 복구
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);

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

  // 녹화 타이머 시작
  void _startRecordingTimer() {
    _recordingSeconds = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingSeconds++;
        });
      }
    });
  }

  // 녹화 타이머 중지
  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  // 녹화 시간을 문자열로 포맷
  String _formatRecordingTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // 비디오 처리를 재시도하는 메서드
  Future<void> _processVideoWithRetry(String originalVideoPath) async {
    for (int attempt = 1; attempt <= _maxProcessingRetries; attempt++) {
      _processingRetryCount = attempt;
      
      try {
        setState(() {
          if (attempt == 1) {
            _statusText = '🎬 고화질 영상 처리 중... (30-60초 소요)';
          } else {
            _statusText = '🔄 영상 처리 재시도 중... ($attempt/$_maxProcessingRetries)';
          }
        });

        // 카메라 프리뷰 영역 크롭 처리 수행
        final processingResult =
            await VideoProcessingService.cropVideoToCameraPreview(
          inputPath: originalVideoPath,
          screenWidth: _screenWidth,
          screenHeight: _screenHeight,
          cameraWidth: _cameraWidth,
          cameraHeight: _cameraHeight,
          leftOffset: _leftOffset,
          topOffset: _topOffset,
          progressCallback: (progress) {
            if (mounted) {
              final progressPercent = (progress * 100).toInt();
              String statusMessage;
              
              if (progressPercent < 30) {
                statusMessage = attempt == 1 
                    ? '🎬 영상 분석 중... $progressPercent%'
                    : '🔄 영상 분석 재시도... $progressPercent% ($attempt/$_maxProcessingRetries)';
              } else if (progressPercent < 80) {
                statusMessage = attempt == 1
                    ? '✂️ 카메라 영역 추출 중... $progressPercent%'
                    : '🔄 영역 추출 재시도... $progressPercent% ($attempt/$_maxProcessingRetries)';
              } else {
                statusMessage = attempt == 1
                    ? '🔧 최종 처리 중... $progressPercent%'
                    : '🔄 최종 처리 재시도... $progressPercent% ($attempt/$_maxProcessingRetries)';
              }
              
              setState(() {
                _statusText = statusMessage;
              });
            }
          },
        );

        // 처리 성공 시
        if (processingResult.success) {
          await _handleProcessingSuccess(processingResult, originalVideoPath);
          return; // 성공 시 재시도 루프 종료
        } else {
          // 처리 실패 시
          if (attempt < _maxProcessingRetries) {
            // 재시도 전 대기
            setState(() {
              _statusText = '⏳ 잠시 후 자동 재시도... (${attempt + 1}/$_maxProcessingRetries)';
            });
            await Future.delayed(Duration(seconds: 2 + attempt)); // 점진적으로 대기 시간 증가
            continue; // 다음 시도로 진행
          } else {
            // 최대 재시도 횟수 초과
            await _handleProcessingFailure(processingResult, originalVideoPath);
            return;
          }
        }
      } catch (e) {
        print('❌ 비디오 처리 시도 $attempt 실패: $e');
        if (attempt < _maxProcessingRetries) {
          setState(() {
            _statusText = '❌ 처리 오류 발생, 자동 재시도 중... (${attempt + 1}/$_maxProcessingRetries)';
          });
          await Future.delayed(Duration(seconds: 3 + attempt));
          continue;
        } else {
          // 최대 재시도 횟수 초과하여 예외 발생
          await _handleProcessingException(e, originalVideoPath);
          return;
        }
      }
    }
  }

  // 처리 성공 시 처리 로직
  Future<void> _handleProcessingSuccess(VideoProcessingResult processingResult, String originalVideoPath) async {
    setState(() {
      _statusText = '✅ 고화질 영상 처리 완료!';
    });

    // VideoPlayer 준비 상태 검증
    final videoReady = await _validateVideoReady(processingResult.outputPath!);

    if (videoReady) {
      setState(() {
        _statusText = '🎉 영상 준비 완료!';
      });

      // 성공 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_processingRetryCount > 1 
                ? '고화질 영상이 준비되었습니다 (재시도 성공)'
                : '고화질 영상이 준비되었습니다'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // 잠시 대기 후 결과 화면으로 이동
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              score: 0,
              totalBalloons: 0,
              videoPath: processingResult.outputPath,
              isOriginalVideo: false,
              originalVideoPath: originalVideoPath,
            ),
          ),
        );
      }
    } else {
      // VideoPlayer 검증 실패
      await _handleVideoValidationFailure(processingResult, originalVideoPath);
    }
  }

  // 처리 실패 시 처리 로직
  Future<void> _handleProcessingFailure(VideoProcessingResult processingResult, String originalVideoPath) async {
    setState(() {
      _statusText = '❌ 영상 처리 최종 실패 ($_maxProcessingRetries회 시도)';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('영상 처리에 $_maxProcessingRetries회 실패했습니다. 에러 정보를 확인해주세요.'),
          duration: Duration(seconds: 3),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            score: 0,
            totalBalloons: 0,
            videoPath: null,
            processingError: processingResult.error,
            originalVideoPath: originalVideoPath,
          ),
        ),
      );
    }
  }

  // VideoPlayer 검증 실패 시 처리 로직
  Future<void> _handleVideoValidationFailure(VideoProcessingResult processingResult, String originalVideoPath) async {
    setState(() {
      _statusText = '❌ 영상 준비 검증 실패';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('영상 준비에 실패했습니다.'),
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            score: 0,
            totalBalloons: 0,
            videoPath: null,
            processingError: VideoProcessingError(
              message: '영상 준비 검증 실패: VideoPlayer 호환성 문제',
              inputPath: originalVideoPath,
              outputPath: processingResult.outputPath,
              ffmpegCommand: 'N/A',
              logs: ['영상 파일은 생성되었으나 VideoPlayer에서 재생할 수 없는 상태'],
              fileInfo: {},
              timestamp: DateTime.now(),
            ),
            originalVideoPath: originalVideoPath,
          ),
        ),
      );
    }
  }

  // 예외 발생 시 처리 로직
  Future<void> _handleProcessingException(dynamic error, String originalVideoPath) async {
    setState(() {
      _statusText = '❌ 영상 처리 중 오류 발생';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('영상 처리 중 오류가 발생했습니다: $error'),
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            score: 0,
            totalBalloons: 0,
            videoPath: null,
            processingError: VideoProcessingError(
              message: '영상 처리 중 예외 발생: $error',
              inputPath: originalVideoPath,
              outputPath: null,
              ffmpegCommand: 'N/A',
              logs: ['예외 발생으로 처리 중단'],
              fileInfo: {},
              timestamp: DateTime.now(),
            ),
            originalVideoPath: originalVideoPath,
          ),
        ),
      );
    }
  }

  // 비디오 파일이 VideoPlayer에서 재생 가능한 상태인지 검증
  Future<bool> _validateVideoReady(String videoPath) async {
    try {
      setState(() {
        _statusText = '🎬 영상 준비 완료 확인 중...';
      });

      // 파일 존재 및 크기 확인
      final videoFile = File(videoPath);
      bool fileExists = false;
      int fileSize = 0;

      // 파일 존재 및 크기 확인 (최대 10초 대기)
      for (int attempt = 1; attempt <= 20; attempt++) {
        setState(() {
          _statusText = '📁 영상 파일 안정화 대기 중... (${(attempt * 0.5).toInt()}초/10초)';
        });
        
        if (await videoFile.exists()) {
          fileSize = await videoFile.length();
          if (fileSize > 1000) { // 1KB 이상이어야 유효한 비디오 파일
            fileExists = true;
            break;
          }
        }
        
        if (attempt < 20) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }

      if (!fileExists || fileSize < 1000) {
        print('❌ 비디오 파일 검증 실패: 존재=$fileExists, 크기=${fileSize}B');
        return false;
      }

      setState(() {
        _statusText = '🔧 비디오 플레이어 호환성 확인 중...';
      });

      // VideoPlayerController로 실제 초기화 테스트 (재시도 로직 포함)
      VideoPlayerController? testController;
      bool canInitialize = false;
      
      // VideoPlayer 초기화를 최대 5회까지 재시도
      for (int testAttempt = 1; testAttempt <= 5; testAttempt++) {
        try {
          setState(() {
            _statusText = testAttempt == 1 
                ? '🔧 비디오 플레이어 호환성 확인 중...'
                : '🔄 비디오 플레이어 재확인 중... ($testAttempt/5)';
          });
          
          // 이전 테스트 컨트롤러가 있으면 정리
          testController?.dispose();
          
          testController = VideoPlayerController.file(videoFile);
          await testController.initialize();
          
          if (testController.value.isInitialized) {
            canInitialize = true;
            print('✅ VideoPlayer 초기화 테스트 성공 (시도: $testAttempt/5)');
            break; // 성공하면 재시도 루프 종료
          }
        } catch (e) {
          print('❌ VideoPlayer 초기화 테스트 실패 (시도: $testAttempt/5): $e');
          
          if (testAttempt < 5) {
            // 재시도 전 대기 시간 (점진적으로 증가)
            final waitTime = Duration(seconds: 1 + testAttempt);
            await Future.delayed(waitTime);
            continue; // 다음 시도로 진행
          }
        } finally {
          // 마지막 시도가 아니면 컨트롤러는 다음 루프에서 정리됨
          if (testAttempt == 5 || canInitialize) {
            testController?.dispose();
          }
        }
      }

      return canInitialize;
    } catch (e) {
      print('❌ 비디오 검증 중 오류: $e');
      return false;
    }
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
      } else {
        // 녹화가 성공적으로 시작되면 타이머 시작
        _startRecordingTimer();
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
    // 타이머 중지
    _stopRecordingTimer();

    setState(() {
      _isRecording = false;
      _isProcessing = true;
      _statusText = '녹화 완료 중...';
    });

    try {
      // flutter_screen_recording으로 녹화 중지 및 파일 경로 받기
      String originalVideoPath = await FlutterScreenRecording.stopRecordScreen;

      if (mounted && originalVideoPath.isNotEmpty) {
        // 재시도 카운터 초기화
        _processingRetryCount = 0;
        
        // 재시도 로직이 포함된 비디오 처리 시작
        await _processVideoWithRetry(originalVideoPath);
        
        // 처리 완료 후 상태 업데이트
        setState(() {
          _isProcessing = false;
        });
      } else {
        setState(() {
          _isProcessing = false;
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
                  return LayoutBuilder(builder: (context, constraints) {
                    // 화면 크기 가져오기
                    final screenWidth = constraints.maxWidth;
                    final screenHeight = constraints.maxHeight;

                    // 9:16 비율 계산
                    final aspectRatio = 9.0 / 16.0;

                    // 너비 기준으로 9:16 비율 높이 계산
                    double cameraWidth = screenWidth;
                    double cameraHeight = screenWidth / aspectRatio;

                    // 화면 높이를 초과하면 높이 기준으로 재계산 (녹화버튼 공간 150px 제외)
                    if (cameraHeight > screenHeight - 150) {
                      cameraHeight = screenHeight - 150;
                      cameraWidth = cameraHeight * aspectRatio;
                    }

                    // 카메라 영역 중앙 배치를 위한 오프셋
                    final leftOffset = (screenWidth - cameraWidth) / 2;
                    final topOffset = (screenHeight - 150 - cameraHeight) / 2;

                    // 카메라 영역 정보 저장 (비디오 처리에서 사용)
                    _screenWidth = screenWidth;
                    _screenHeight = screenHeight;
                    _cameraWidth = cameraWidth;
                    _cameraHeight = cameraHeight;
                    _leftOffset = leftOffset;
                    _topOffset = topOffset;

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // 9:16 비율 CameraPreview (중앙 배치)
                        Positioned(
                          left: leftOffset,
                          top: topOffset,
                          width: cameraWidth,
                          height: cameraHeight,
                          child: ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.center,
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: cameraWidth,
                                  height: cameraHeight,
                                  child: CameraPreview(_controller!),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 이마 이미지 오버레이 (얼굴이 감지되고 이마 사각형이 있을 때만)
                        if (_currentForeheadRectangle != null &&
                            _currentForeheadRectangle!.isValid)
                          Positioned(
                            left: leftOffset,
                            top: topOffset,
                            width: cameraWidth,
                            height: cameraHeight,
                            child: CustomPaint(
                              painter: ForeheadImagePainter(
                                foreheadRectangle: _currentForeheadRectangle!,
                                imageSize: Size(
                                  _controller!.value.previewSize!.height,
                                  _controller!.value.previewSize!.width,
                                ),
                                screenSize: Size(
                                  cameraWidth,
                                  cameraHeight, // 9:16 비율 영역 크기 사용
                                ),
                                currentItemName: ref
                                        .watch(currentRankingItemProvider)
                                        ?.name ??
                                    "",
                              ),
                            ),
                          ),
                        // 랭킹 슬롯 패널 (9:16 카메라 영역 내 왼쪽 하단에 배치)
                        Positioned(
                          left: leftOffset,
                          bottom:
                              screenHeight - (topOffset + cameraHeight) + 60,
                          child: const RankingSlotPanel(),
                        ),
                        // 녹화 시간 표시 (녹화 중일 때만, 녹화버튼 우측에)
                        if (_isRecording)
                          Positioned(
                            bottom: 65,
                            right: 50,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _formatRecordingTime(_recordingSeconds),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),

                        // 처리 상태 표시 (처리 중일 때만)
                        if (_isProcessing)
                          Positioned(
                            bottom: 120,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 20),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.purple.withValues(alpha: 0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: CircularProgressIndicator(
                                        color: Colors.purple,
                                        strokeWidth: 3,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _statusText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      '잠시만 기다려주세요',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        // 중앙 하단 녹화 버튼
                        Positioned(
                          bottom: 50,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: _isProcessing
                                  ? null
                                  : _isRecording
                                      ? _stopRecording
                                      : _startRecording,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isRecording
                                      ? Colors.red
                                      : _isProcessing
                                          ? Colors.grey
                                          : Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  _isRecording
                                      ? Icons.stop
                                      : _isProcessing
                                          ? Icons.hourglass_empty
                                          : Icons.videocam,
                                  size: 36,
                                  color: _isRecording
                                      ? Colors.white
                                      : _isProcessing
                                          ? Colors.white
                                          : Colors.red,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 뒤로가기 버튼 오버레이 (녹화 중이거나 처리 중이 아닐 때만 표시)
                        if (!_isRecording && !_isProcessing)
                          Positioned(
                            top: 0,
                            left: 0,
                            child: SafeArea(
                              child: Container(
                                margin: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.arrow_back),
                                  color: Colors.white,
                                  iconSize: 24,
                                ),
                              ),
                            ),
                          ),
                        // 카메라 전환 버튼 오버레이 (녹화 중이거나 처리 중이 아닐 때만 표시)
                        if (cameras.length > 1 && !_isRecording && !_isProcessing)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: SafeArea(
                              child: Container(
                                margin: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: IconButton(
                                  onPressed: _toggleCamera,
                                  icon: const Icon(
                                      CupertinoIcons.switch_camera_solid),
                                  color: Colors.white,
                                  iconSize: 24,
                                ),
                              ),
                            ),
                          ),
                        
                        // 크롭 영역 토글 버튼 (녹화 중이거나 처리 중이 아닐 때만 표시)
                        if (!_isRecording && !_isProcessing)
                          Positioned(
                            top: 0,
                            right: cameras.length > 1 ? 72 : 16,
                            child: SafeArea(
                              child: Container(
                                margin: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _showCropArea = !_showCropArea;
                                    });
                                  },
                                  icon: Icon(
                                    _showCropArea
                                        ? Icons.crop_free
                                        : Icons.crop,
                                  ),
                                  color: _showCropArea ? Colors.red : Colors.white,
                                  iconSize: 24,
                                ),
                              ),
                            ),
                          ),

                        // 크롭 영역 시각화 (빨간 사각형)
                        if (_showCropArea)
                          Positioned(
                            left: leftOffset,
                            top: topOffset,
                            width: cameraWidth,
                            height: cameraHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.red,
                                  width: 3.0,
                                ),
                              ),
                              child: Container(
                                color: Colors.red.withValues(alpha: 0.1),
                              ),
                            ),
                          ),

                        // 디버그 정보 표시 (크롭 영역 표시 중일 때만)
                        if (_showCropArea)
                          Positioned(
                            left: 16,
                            bottom: 180,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '🎯 크롭 영역 정보',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '화면 크기: ${screenWidth.toInt()}×${screenHeight.toInt()}',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                  Text(
                                    '카메라 영역: ${cameraWidth.toInt()}×${cameraHeight.toInt()}',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                  Text(
                                    '오프셋: (${leftOffset.toInt()}, ${topOffset.toInt()})',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '크롭 비율:',
                                    style: TextStyle(color: Colors.yellow, fontSize: 12),
                                  ),
                                  Text(
                                    '  Width: ${(cameraWidth / screenWidth * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                  Text(
                                    '  Height: ${(cameraHeight / screenHeight * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                  Text(
                                    '  X: ${(leftOffset / screenWidth * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                  Text(
                                    '  Y: ${(topOffset / screenHeight * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  });
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
