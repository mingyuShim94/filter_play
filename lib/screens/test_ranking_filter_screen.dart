import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

// 랭킹 게임 관련 imports
import '../providers/ranking_game_provider.dart';
import '../providers/filter_provider.dart';
import '../services/ranking_data_service.dart';
import '../widgets/ranking_slot_panel.dart';

class TestRankingFilterScreen extends ConsumerStatefulWidget {
  const TestRankingFilterScreen({super.key});

  @override
  ConsumerState<TestRankingFilterScreen> createState() =>
      _TestRankingFilterScreenState();
}

class _TestRankingFilterScreenState
    extends ConsumerState<TestRankingFilterScreen> {
  // Screenshot 컨트롤러
  final ScreenshotController _screenshotController = ScreenshotController();

  // 카메라 관련 상태 변수
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  List<CameraDescription> cameras = [];
  int _selectedCameraIndex = 0;
  bool _permissionGranted = false;
  bool _permissionRequested = false;

  // 녹화 관련 상태 변수 (ValueNotifier 사용)
  final ValueNotifier<bool> _isRecordingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isProcessingNotifier = ValueNotifier(false);
  final ValueNotifier<String> _statusNotifier = ValueNotifier('녹화 준비 완료');
  final ValueNotifier<int> _frameCountNotifier = ValueNotifier(0);

  // Isolate 파일 저장 시스템
  final IsolateFileSaver _isolateFileSaver = IsolateFileSaver();
  bool _isLoopActive = false; // async 루프 제어 플래그

  final AudioRecorder _audioRecorder = AudioRecorder();
  Directory? _sessionDirectory; // 녹화 세션용 임시 디렉토리

  // 정확한 녹화 시간 측정을 위한 Stopwatch
  final Stopwatch _recordingStopwatch = Stopwatch();
  DateTime? _recordingStartTime; // 녹화 시작 시간 (백업용)

  @override
  void initState() {
    super.initState();

    // Isolate 파일 저장 시스템 시작
    _isolateFileSaver.start().then((_) {
      print("🪡 Isolate File Saver가 준비되었습니다.");
    }).catchError((e) {
      print("❌ Isolate File Saver 시작 실패: $e");
    });

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
    // 모든 리소스 정리
    _isLoopActive = false; // async 루프 중지
    _isolateFileSaver.stop(); // Isolate 정리
    _audioRecorder.dispose();
    _controller?.dispose();

    // ValueNotifier 들 정리
    _isRecordingNotifier.dispose();
    _isProcessingNotifier.dispose();
    _statusNotifier.dispose();
    _frameCountNotifier.dispose();

    super.dispose();
  }

  Future<void> _requestPermissionsAndInitialize() async {
    try {
      setState(() {
        _permissionRequested = true;
      });

      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      if (statuses[Permission.camera] == PermissionStatus.granted) {
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
      setState(() {});
    }).catchError((error) {
      print(error);
    });
  }

  void _toggleCamera() async {
    if (cameras.isEmpty || cameras.length < 2) {
      print('Can\'t toggle camera. not enough cameras available');
      return;
    }

    _selectedCameraIndex = (_selectedCameraIndex + 1) % cameras.length;

    setState(() {});

    await _initializeCamera(cameras[_selectedCameraIndex]);
  }

  // 녹화 시작
  Future<void> _startRecording() async {
    // 이미 녹화/처리 중이면 중복 실행 방지
    if (_isRecordingNotifier.value || _isProcessingNotifier.value) return;

    // 세션 디렉토리 생성
    final tempDir = await getTemporaryDirectory();
    _sessionDirectory = Directory(
        '${tempDir.path}/record_${DateTime.now().millisecondsSinceEpoch}');
    await _sessionDirectory!.create();

    // ValueNotifier 업데이트 (setState 대신)
    _isRecordingNotifier.value = true;
    _statusNotifier.value = '녹화 중...';
    _frameCountNotifier.value = 0;

    try {
      // 정확한 녹화 시간 측정 시작
      _recordingStopwatch.reset();
      _recordingStopwatch.start();
      _recordingStartTime = DateTime.now();
      print('녹화 시작: $_recordingStartTime');

      // 오디오 녹음 시작
      final audioPath = '${_sessionDirectory!.path}/audio.m4a';
      await _audioRecorder.start(const RecordConfig(), path: audioPath);
      print('오디오 녹음 시작: $audioPath');

      // async 루프 시작 (Timer 대신)
      _isLoopActive = true;
      _frameCaptureLoop();
    } catch (e) {
      print("녹화 시작 오류: $e");
      _isRecordingNotifier.value = false;
      _statusNotifier.value = '녹화 시작 실패';
    }
  }

  // 새로운 지능적 프레임 캡처 루프 (Timer 대체)
  Future<void> _frameCaptureLoop() async {
    const targetFrameInterval = Duration(milliseconds: 50); // 20fps 목표

    while (_isLoopActive && mounted) {
      final frameStopwatch = Stopwatch()..start();

      // 캡처 및 Isolate 전송
      await _captureAndSaveFrame();

      // 목표 FPS에 맞게 대기
      final elapsed = frameStopwatch.elapsed;
      if (elapsed < targetFrameInterval) {
        await Future.delayed(targetFrameInterval - elapsed);
      }
    }
  }

  // 완전히 새로워진 캡처 및 저장 메서드 (PNG 직접 저장, UI 스레드 최적화)
  Future<void> _captureAndSaveFrame() async {
    if (!mounted) return;

    try {
      // 1. Screenshot 패키지로 PNG 데이터 캡처 (가장 가벼운 작업)
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: 1.5,
        delay: Duration.zero, // 딜레이 최소화
      );

      if (imageBytes != null) {
        // 2. 파일 이름에 .png 확장자 사용
        final fileName =
            'frame_${(_frameCountNotifier.value + 1).toString().padLeft(5, '0')}.png';
        final filePath = '${_sessionDirectory!.path}/$fileName';

        // 3. PNG 데이터를 그대로 Isolate로 보내 파일 저장 요청 (UI 스레드 차단 없음!)
        final saveSuccess = _isolateFileSaver.saveFrame(filePath, imageBytes);

        if (saveSuccess) {
          _frameCountNotifier.value++;
          _statusNotifier.value =
              '녹화 중... ${_frameCountNotifier.value} 프레임 [미처리: ${_isolateFileSaver.pendingWrites}]';
        }
      }
    } catch (e) {
      print("프레임 캡쳐/저장 오류: $e");
    }
  }

  // 녹화 중지
  Future<void> _stopRecording() async {
    if (!_isRecordingNotifier.value) return;

    // async 루프 중지
    _isLoopActive = false;

    // 정확한 녹화 시간 측정 종료
    _recordingStopwatch.stop();
    final recordingDuration =
        _recordingStopwatch.elapsedMilliseconds / 1000.0; // 초 단위
    print(
        '녹화 종료 - 실제 녹화 시간: $recordingDuration초, 캡쳐된 프레임: ${_frameCountNotifier.value}');

    // ValueNotifier 업데이트 (setState 대신)
    _isRecordingNotifier.value = false;
    _isProcessingNotifier.value = true;
    _statusNotifier.value = '녹화 중지됨, 영상 처리 시작...';

    // 오디오 녹음 종료
    await _audioRecorder.stop();
    print('오디오 녹음 종료');

    // 모든 프레임이 디스크에 저장될 때까지 대기
    while (_isolateFileSaver.pendingWrites > 0) {
      _statusNotifier.value =
          '남은 프레임 저장 중... (${_isolateFileSaver.pendingWrites}개)';
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // 비동기로 오디오 싱크 영상 합성 실행
    _executeFFmpegWithActualFPS();
  }

  // 실제 평균 FPS 계산 및 FFmpeg 실행
  Future<void> _executeFFmpegWithActualFPS() async {
    final recordingDuration =
        _recordingStopwatch.elapsedMilliseconds / 1000.0; // 초 단위
    final capturedFrames = _frameCountNotifier.value;

    if (recordingDuration <= 0 || capturedFrames <= 0) {
      _statusNotifier.value = '녹화 데이터가 유효하지 않습니다.';
      _isProcessingNotifier.value = false;
      return;
    }

    // 실제 평균 FPS 계산 (핵심 로직!)
    final actualAverageFPS = capturedFrames / recordingDuration;

    print('▶ 오디오 싱크 계산:');
    print('  - 실제 녹화 시간: $recordingDuration초');
    print('  - 캡쳐된 프레임: $capturedFrames개');
    print('  - 실제 평균 FPS: ${actualAverageFPS.toStringAsFixed(2)}');

    // 최종 결과물 경로
    final documentsDir = await getApplicationDocumentsDirectory();
    final outputPath =
        '${documentsDir.path}/synced_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final audioPath = '${_sessionDirectory!.path}/audio.m4a';

    // 오디오 파일 존재 확인
    final audioFile = File(audioPath);
    final audioExists = await audioFile.exists();

    if (!audioExists) {
      print('⚠️ 오디오 파일을 찾을 수 없습니다: $audioPath');
      _statusNotifier.value = '오디오 파일을 찾을 수 없습니다.';
      _isProcessingNotifier.value = false;
      return;
    }

    // 플랫폼별 최적화된 인코더 설정
    final videoEncoder = Platform.isIOS ? 'h264_videotoolbox' : 'libx264';
    final videoSettings = Platform.isIOS
        ? '-c:v $videoEncoder -realtime 1 -pix_fmt yuv420p'
        : '-c:v $videoEncoder -preset ultrafast -crf 28 -pix_fmt yuv420p';

    // PNG 이미지 시퀀스를 입력으로 사용하는 FFmpeg 명령어
    final imageInputPath = '${_sessionDirectory!.path}/frame_%05d.png';

    final command = '-framerate ${actualAverageFPS.toStringAsFixed(2)} '
        '-i "$imageInputPath" '
        '-i "$audioPath" '
        '$videoSettings '
        '-c:a aac '
        '-shortest '
        '-y "$outputPath"';

    print('▶ FFmpeg 명령어 (PNG 시퀀스 적용):');
    print('  $command');

    _statusNotifier.value = 'FFmpeg으로 PNG 시퀀스 영상 합성 중...';

    await FFmpegKit.execute(command).then((session) async {
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        print('✅ 오디오 싱크 영상 합성 성공: $outputPath');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('오디오 싱크 영상 저장 성공! ${outputPath.split('/').last}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        _statusNotifier.value = '오디오 싱크 영상 저장 완료!';
      } else {
        final errorLogs = await session.getAllLogsAsString();
        print('❌ 오디오 싱크 영상 합성 실패.');
        print('FFmpeg 오류 로그: $errorLogs');
        _statusNotifier.value = '오디오 싱크 영상 합성 실패';
      }
    });

    _isProcessingNotifier.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Camera Preview'),
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
                  if (_permissionRequested && !_permissionGranted) ...[
                    const SizedBox(height: 8),
                    Text(
                      "설정에서 카메라 권한을 허용해주세요",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                  // Screenshot 위젯으로 캡쳐 영역 감싸기
                  return Screenshot(
                    controller: _screenshotController,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_controller!),
                        // 랭킹 슬롯 패널 (왼쪽) - 별도 RepaintBoundary로 렌더링 최적화
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: RepaintBoundary(
                            child: const RankingSlotPanel(),
                          ),
                        ),
                        // 녹화 상태를 표시하는 오버레이
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ValueListenableBuilder<String>(
                              valueListenable: _statusNotifier,
                              builder: (context, status, child) {
                                return Text(
                                  status,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                );
                              },
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
      // 녹화 시작/중지 버튼
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _isProcessingNotifier,
        builder: (context, isProcessing, child) {
          return ValueListenableBuilder<bool>(
            valueListenable: _isRecordingNotifier,
            builder: (context, isRecording, child) {
              return FloatingActionButton(
                onPressed: isProcessing
                    ? null
                    : (isRecording ? _stopRecording : _startRecording),
                backgroundColor: isProcessing
                    ? Colors.grey
                    : (isRecording ? Colors.red : Colors.green),
                child: Icon(isRecording ? Icons.stop : Icons.videocam),
              );
            },
          );
        },
      ),
    );
  }
}

// Isolate 진입점 함수 (파일 저장 전용)
void saveFrameIsolateEntry(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    if (message is Map<String, dynamic>) {
      final action = message['action'] as String;

      if (action == 'save') {
        final filePath = message['filePath'] as String;
        final imageData = message['imageData'] as Uint8List;

        try {
          final file = File(filePath);
          file.writeAsBytesSync(imageData, flush: true);
          sendPort.send({'status': 'success', 'filePath': filePath});
        } catch (e) {
          sendPort.send({'status': 'error', 'error': e.toString()});
        }
      } else if (action == 'stop') {
        receivePort.close();
      }
    }
  });
}

// Isolate 파일 저장 관리 클래스
class IsolateFileSaver {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  int _pendingWrites = 0;

  int get pendingWrites => _pendingWrites;

  Future<void> start() async {
    _receivePort = ReceivePort();

    _isolate = await Isolate.spawn(
      saveFrameIsolateEntry,
      _receivePort!.sendPort,
    );

    final completer = Completer<SendPort>();
    _receivePort!.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message is Map<String, dynamic>) {
        final status = message['status'] as String;
        if (status == 'success' || status == 'error') {
          _pendingWrites =
              (_pendingWrites - 1).clamp(0, double.infinity).toInt();
        }
        if (status == 'error') {
          print('Isolate 파일 저장 오류: ${message['error']}');
        }
      }
    });

    _sendPort = await completer.future;
  }

  bool saveFrame(String filePath, Uint8List imageData) {
    if (_sendPort == null) return false;

    _sendPort!.send({
      'action': 'save',
      'filePath': filePath,
      'imageData': imageData,
    });

    _pendingWrites++;
    return true;
  }

  void stop() {
    if (_sendPort != null) {
      _sendPort!.send({'action': 'stop'});
    }
    _isolate?.kill();
    _receivePort?.close();

    _isolate = null;
    _sendPort = null;
    _receivePort = null;
    _pendingWrites = 0;
  }
}
