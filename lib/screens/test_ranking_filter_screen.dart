import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

// 랭킹 게임 관련 imports
import '../providers/ranking_game_provider.dart';
import '../providers/filter_provider.dart';
import '../services/ranking_data_service.dart';
import '../widgets/ranking_slot_panel.dart';
import 'result_screen.dart';

class TestRankingFilterScreen extends ConsumerStatefulWidget {
  const TestRankingFilterScreen({super.key});

  @override
  ConsumerState<TestRankingFilterScreen> createState() =>
      _TestRankingFilterScreenState();
}

class _TestRankingFilterScreenState
    extends ConsumerState<TestRankingFilterScreen> {
  // 캡쳐 영역을 위한 GlobalKey
  final GlobalKey _captureKey = GlobalKey();

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

  Timer? _frameCaptureTimer;
  final AudioRecorder _audioRecorder = AudioRecorder();
  Directory? _sessionDirectory; // 녹화 세션용 임시 디렉토리
  bool _isCapturingFrame = false; // 중복 캡쳐 방지 플래그

  // 정확한 녹화 시간 측정을 위한 Stopwatch
  final Stopwatch _recordingStopwatch = Stopwatch();
  DateTime? _recordingStartTime; // 녹화 시작 시간 (백업용)

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
    // 모든 리소스 정리
    _frameCaptureTimer?.cancel();
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
    _statusNotifier.value = '녹화 중... 0 프레임';
    _frameCountNotifier.value = 0;
    _isCapturingFrame = false;

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

      // 프레임 캡쳐 타이머 시작 (20fps 목표)
      _frameCaptureTimer =
          Timer.periodic(const Duration(milliseconds: 50), (timer) {
        // Flutter 렌더링이 완료된 직후에 캡쳐를 예약
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isRecordingNotifier.value && mounted) {
            _captureFrameForRecording();
          }
        });
      });
    } catch (e) {
      print("녹화 시작 오류: $e");
      _isRecordingNotifier.value = false;
      _statusNotifier.value = '녹화 시작 실패';
    }
  }

  // 프레임 캡쳐 메서드 (RepaintBoundary 최적화 적용)
  Future<void> _captureFrameForRecording() async {
    if (!mounted || _isCapturingFrame) return; // 위젯 unmount 또는 중복 실행 방지

    _isCapturingFrame = true;
    final captureStartTime = DateTime.now(); // 성능 측정

    try {
      RenderRepaintBoundary boundary = _captureKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      // 1.5배 해상도로 캡쳐 (품질과 성능의 균형점)
      const double pixelRatio = 1.5;
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);

      // RawRGBA 포맷으로 변환 (가장 빠름)
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose(); // 이미지 메모리 즉시 해제

      if (byteData != null) {
        final Uint8List rawBytes = byteData.buffer.asUint8List();
        final fileName =
            'frame_${(_frameCountNotifier.value + 1).toString().padLeft(5, '0')}_${image.width}x${image.height}.raw';
        final file = File('${_sessionDirectory!.path}/$fileName');

        // 파일에 비동기로 쓰기 (UI 스레드 차단 최소화)
        await file.writeAsBytes(rawBytes, flush: true);

        // setState 대신 ValueNotifier 업데이트 (성능 향상의 핵심!)
        _frameCountNotifier.value = _frameCountNotifier.value + 1;
        _statusNotifier.value = '녹화 중... ${_frameCountNotifier.value} 프래임';

        // RepaintBoundary 최적화 효과 모니터링
        final captureEndTime = DateTime.now();
        final captureDuration =
            captureEndTime.difference(captureStartTime).inMilliseconds;

        // 성능 지수로 RepaintBoundary 효과 평가
        if (captureDuration > 40) {
          print(
              '\x1b[91m🎬 ⚠️ RepaintBoundary 최적화 부족: ${captureDuration}ms (UI 스레드 경합)\x1b[0m');
        } else if (captureDuration > 20) {
          print(
              '\x1b[93m🎬 ⚡ RepaintBoundary 효과 보통: ${captureDuration}ms\x1b[0m');
        } else if (_frameCountNotifier.value % 20 == 0) {
          // 20프레임마다 로그
          print(
              '\x1b[92m🎬 ✅ RepaintBoundary 최적화 성공: ${captureDuration}ms (프레임: ${_frameCountNotifier.value})\x1b[0m');
        }
      }
    } catch (e) {
      print("프레임 캡쳐 오류: $e");
    } finally {
      _isCapturingFrame = false;
    }
  }

  // 녹화 중지
  Future<void> _stopRecording() async {
    if (!_isRecordingNotifier.value) return;

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

    // 타이머 정지 및 오디오 녹음 종료
    _frameCaptureTimer?.cancel();
    await _audioRecorder.stop();
    print('오디오 녹음 종료');

    // 비동기로 오디오 싱크 영상 합성 실행
    _executeFFmpegWithActualFPS();
  }

  // 레거시 _composeVideo (이제 사용하지 않음)
  // 새로운 _executeFFmpegWithActualFPS 메서드가 오디오 싱크 문제를 해결합니다

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

    // .raw 파일 리스트 가져오기
    final rawFiles = _sessionDirectory!
        .listSync()
        .where((file) => file is File && file.path.endsWith('.raw'))
        .cast<File>()
        .toList();
    rawFiles.sort((a, b) => a.path.compareTo(b.path));

    // 첫 프레임 파일명에서 해상도 추출
    final firstFileName = rawFiles.first.path.split('/').last;
    final match = RegExp(r'frame_\d+_(\d+x\d+)\.raw').firstMatch(firstFileName);
    if (match == null || match.group(1) == null) {
      _statusNotifier.value = '해상도 정보를 찾을 수 없습니다.';
      _isProcessingNotifier.value = false;
      return;
    }
    final String videoSize = match.group(1)!;

    // Raw 프레임들을 하나의 파일로 합치기
    final concatenatedRawPath = '${_sessionDirectory!.path}/video.raw';
    final sink = File(concatenatedRawPath).openWrite();
    for (final file in rawFiles) {
      sink.add(await file.readAsBytes());
    }
    await sink.close();

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

    // 핵심! 실제 FPS를 사용한 FFmpeg 명령어 구성
    final command = '-f rawvideo -pixel_format rgba -video_size $videoSize '
        '-r ${actualAverageFPS.toStringAsFixed(2)} '
        '-i "$concatenatedRawPath" '
        '-i "$audioPath" '
        '$videoSettings '
        '-c:a aac '
        '-shortest '
        '-y "$outputPath"';

    print('▶ FFmpeg 명령어 (오디오 싱크 적용):');
    print('  $command');

    _statusNotifier.value = 'FFmpeg으로 오디오 싱크 영상 합성 중...';

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
                  // RepaintBoundary로 캡쳐 영역 감싸기
                  return RepaintBoundary(
                    key: _captureKey,
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
                              color: Colors.black.withOpacity(0.5),
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
