import 'dart:async';
import 'dart:io';

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as path;

void main() {
  runApp(const CustomScreenRecorderApp());
}

class CustomScreenRecorderApp extends StatelessWidget {
  const CustomScreenRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Custom Screen Recorder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ScreenRecorderHome(),
    );
  }
}

class ScreenRecorderHome extends StatefulWidget {
  const ScreenRecorderHome({super.key});

  @override
  State<ScreenRecorderHome> createState() => _ScreenRecorderHomeState();
}

class _ScreenRecorderHomeState extends State<ScreenRecorderHome> {
  final GlobalKey _globalKey = GlobalKey();
  Timer? _captureTimer;

  // ValueNotifiers for efficient state management
  final ValueNotifier<List<int>> _filledButtonsNotifier =
      ValueNotifier<List<int>>([]);
  final ValueNotifier<bool> _isRecordingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> _frameCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<String> _lastSavedPathNotifier =
      ValueNotifier<String>('');
  final ValueNotifier<double> _actualFpsNotifier = ValueNotifier<double>(0.0);

  // Video composition ValueNotifiers
  final ValueNotifier<bool> _isProcessingVideoNotifier =
      ValueNotifier<bool>(false);
  final ValueNotifier<String> _processingStatusNotifier =
      ValueNotifier<String>('');
  final ValueNotifier<String> _finalVideoPathNotifier =
      ValueNotifier<String>('');

  // Recording session management
  DateTime? _recordingStartTime;
  DateTime? _recordingEndTime;
  Directory? _sessionDirectory;
  Size? _frameSize;

  // FPS calculation
  DateTime? _lastCaptureTime;
  final List<Duration> _captureDurations = [];

  @override
  void dispose() {
    _stopCapture();
    _filledButtonsNotifier.dispose();
    _isRecordingNotifier.dispose();
    _frameCountNotifier.dispose();
    _lastSavedPathNotifier.dispose();
    _actualFpsNotifier.dispose();
    _isProcessingVideoNotifier.dispose();
    _processingStatusNotifier.dispose();
    _finalVideoPathNotifier.dispose();
    super.dispose();
  }

  void _onButtonPressed(int index) {
    final currentFilledButtons = List<int>.from(_filledButtonsNotifier.value);
    if (currentFilledButtons.contains(index)) {
      currentFilledButtons.remove(index);
    } else {
      currentFilledButtons.add(index);
    }
    _filledButtonsNotifier.value = currentFilledButtons;
  }

  void _clearGrid() {
    _filledButtonsNotifier.value = [];
  }

  Future<void> _createSessionDirectory() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      _sessionDirectory =
          Directory('${tempDir.path}/screen_record_session_$timestamp');
      await _sessionDirectory!.create(recursive: true);
      debugPrint('세션 디렉토리 생성: ${_sessionDirectory!.path}');
    } catch (e) {
      debugPrint('세션 디렉토리 생성 실패: $e');
    }
  }

  Future<void> _startCapture() async {
    if (_captureTimer?.isActive == true) return;

    await _createSessionDirectory();

    _recordingStartTime = DateTime.now();
    _recordingEndTime = null;
    _isRecordingNotifier.value = true;
    _frameCountNotifier.value = 0;
    _captureDurations.clear();
    _lastCaptureTime = DateTime.now();
    _processingStatusNotifier.value = '';
    _finalVideoPathNotifier.value = '';

    // 50ms = 20fps
    _captureTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _captureFrame();
        });
      }
    });
  }

  void _stopCapture() {
    _captureTimer?.cancel();
    _captureTimer = null;
    _recordingEndTime = DateTime.now();
    _isRecordingNotifier.value = false;
  }

  Future<void> _captureFrame() async {
    if (_globalKey.currentContext == null || _sessionDirectory == null) return;

    try {
      // Calculate FPS
      final now = DateTime.now();
      if (_lastCaptureTime != null) {
        final duration = now.difference(_lastCaptureTime!);
        _captureDurations.add(duration);

        // Keep only last 10 measurements for smooth average
        if (_captureDurations.length > 10) {
          _captureDurations.removeAt(0);
        }

        // Calculate average FPS
        final avgDuration =
            _captureDurations.fold<int>(0, (sum, d) => sum + d.inMilliseconds) /
                _captureDurations.length;

        _actualFpsNotifier.value = 1000 / avgDuration;
      }
      _lastCaptureTime = now;

      final RenderRepaintBoundary boundary = _globalKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);

      // Store frame size for FFmpeg (only once)
      if (_frameSize == null) {
        _frameSize = Size(image.width.toDouble(), image.height.toDouble());
        debugPrint('프레임 크기 설정: ${image.width}x${image.height}');
      }

      // Convert to Raw RGBA format
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final Uint8List? rawBytes = byteData?.buffer.asUint8List();

      if (rawBytes != null) {
        await _saveRawFrame(rawBytes);
        _frameCountNotifier.value = _frameCountNotifier.value + 1;
      }
    } catch (e) {
      debugPrint('캡쳐 실패: $e');
    }
  }

  Future<void> _saveRawFrame(Uint8List rawBytes) async {
    try {
      if (_sessionDirectory == null) return;

      // Zero-padded frame number for proper ordering
      final String frameNumber =
          _frameCountNotifier.value.toString().padLeft(6, '0');
      final String fileName = 'frame_$frameNumber.raw';
      final File file = File('${_sessionDirectory!.path}/$fileName');

      await file.writeAsBytes(rawBytes);
      _lastSavedPathNotifier.value = file.path;
    } catch (e) {
      debugPrint('Raw 프레임 저장 실패: $e');
    }
  }

  Future<void> _composeVideo() async {
    if (_sessionDirectory == null || _frameSize == null) {
      _processingStatusNotifier.value = '오류: 세션 정보가 없습니다';
      return;
    }

    _isProcessingVideoNotifier.value = true;
    _processingStatusNotifier.value = '영상 합성 시작...';

    try {
      // 1. 실제 FPS 계산
      double actualFps = 20.0; // 기본값
      if (_recordingStartTime != null && _recordingEndTime != null) {
        final actualRecordingDuration =
            _recordingEndTime!.difference(_recordingStartTime!);
        final actualRecordingSeconds =
            actualRecordingDuration.inMilliseconds / 1000.0;
        if (actualRecordingSeconds > 0) {
          actualFps = _frameCountNotifier.value / actualRecordingSeconds;
        }
        debugPrint('실제 녹화 시간: ${actualRecordingSeconds.toStringAsFixed(2)}초');
        debugPrint('실제 FPS: ${actualFps.toStringAsFixed(2)}');
      }

      // 2. Raw 프레임 파일들 수집 및 정렬
      _processingStatusNotifier.value = 'Raw 프레임 파일 수집 중...';
      final rawFiles = _sessionDirectory!
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.raw'))
          .toList();

      // 파일명 기준으로 정렬 (frame_000001.raw, frame_000002.raw, ...)
      rawFiles.sort(
          (a, b) => path.basename(a.path).compareTo(path.basename(b.path)));

      debugPrint('수집된 Raw 프레임 파일 수: ${rawFiles.length}');

      if (rawFiles.isEmpty) {
        _processingStatusNotifier.value = '오류: Raw 프레임 파일이 없습니다';
        return;
      }

      // 3. 모든 Raw 프레임을 하나의 파일로 통합
      _processingStatusNotifier.value = 'Raw 프레임 통합 중...';
      final concatenatedRawPath = '${_sessionDirectory!.path}/video.raw';
      final concatenatedFile = File(concatenatedRawPath);
      final sink = concatenatedFile.openWrite();

      for (int i = 0; i < rawFiles.length; i++) {
        final file = rawFiles[i];
        final bytes = await file.readAsBytes();
        sink.add(bytes);

        // 진행률 업데이트
        final progress = ((i + 1) / rawFiles.length * 100).toInt();
        _processingStatusNotifier.value = 'Raw 프레임 통합 중... ($progress%)';
      }
      await sink.close();

      // 4. FFmpeg 명령어 생성 및 실행
      _processingStatusNotifier.value = 'FFmpeg 영상 인코딩 중...';
      await _executeFFmpeg(concatenatedRawPath, actualFps);
    } catch (e) {
      debugPrint('영상 합성 실패: $e');
      _processingStatusNotifier.value = '영상 합성 실패: $e';
    } finally {
      _isProcessingVideoNotifier.value = false;
    }
  }

  Future<void> _executeFFmpeg(
      String concatenatedRawPath, double actualFps) async {
    try {
      if (_frameSize == null) {
        _processingStatusNotifier.value = '오류: 프레임 크기 정보가 없습니다';
        return;
      }

      // 입력 파일 검증
      final concatenatedFile = File(concatenatedRawPath);
      if (!await concatenatedFile.exists()) {
        _processingStatusNotifier.value = '오류: 통합된 Raw 파일이 존재하지 않습니다';
        return;
      }

      final fileSize = await concatenatedFile.length();
      debugPrint(
          '통합된 Raw 파일 크기: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      final videoSize =
          '${_frameSize!.width.toInt()}x${_frameSize!.height.toInt()}';
      final outputPath = '${_sessionDirectory!.path}/output_video.mp4';

      // 출력 디렉토리 확인
      final outputDir = Directory(_sessionDirectory!.path);
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      debugPrint('영상 변환 정보:');
      debugPrint('  - 입력: $concatenatedRawPath');
      debugPrint('  - 출력: $outputPath');
      debugPrint('  - 해상도: $videoSize');
      debugPrint('  - FPS: ${actualFps.toStringAsFixed(2)}');
      debugPrint('  - 플랫폼: ${Platform.isIOS ? "iOS" : "Android"}');

      // FFmpeg 명령어 구성
      final videoInput =
          '-f rawvideo -pixel_format rgba -video_size $videoSize -framerate ${actualFps.toStringAsFixed(2)} -i "$concatenatedRawPath"';

      // 플랫폼별 최적화된 비디오 인코더
      final videoEncoder = Platform.isIOS ? 'h264_videotoolbox' : 'libx264';

      final videoOutput = Platform.isIOS
          ? '-c:v $videoEncoder -realtime 1 -pix_fmt yuv420p'
          : '-c:v $videoEncoder -preset ultrafast -crf 28 -g 30 -threads 0 -pix_fmt yuv420p';

      final command = '$videoInput $videoOutput "$outputPath"';

      debugPrint('실행할 FFmpeg 명령어: $command');

      // FFmpeg 실행 (FFmpegKit은 자동으로 ffmpeg를 호출하므로 prefix 불필요)
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        // 출력 파일 검증
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          final outputSize = await outputFile.length();
          debugPrint(
              '생성된 영상 파일 크기: ${(outputSize / 1024 / 1024).toStringAsFixed(2)} MB');

          _processingStatusNotifier.value =
              '영상 생성 완료! (${(outputSize / 1024 / 1024).toStringAsFixed(1)}MB)';
          _finalVideoPathNotifier.value = outputPath;

          // Raw 파일들 정리
          await _cleanupRawFrames();

          debugPrint('영상 생성 성공: $outputPath');
        } else {
          _processingStatusNotifier.value = '오류: 출력 파일이 생성되지 않았습니다';
          debugPrint('경고: FFmpeg가 성공했다고 보고했지만 출력 파일이 없습니다');
        }
      } else {
        // 상세한 오류 분석
        final logs = await session.getAllLogsAsString();
        debugPrint('FFmpeg 실패 로그: $logs');

        // 일반적인 오류 패턴 분석
        String errorMessage = 'FFmpeg 실행 실패';
        if (logs != null) {
          if (logs.contains('No such file or directory')) {
            errorMessage = '오류: 입력 파일을 찾을 수 없습니다';
          } else if (logs.contains('Permission denied')) {
            errorMessage = '오류: 파일 권한 문제';
          } else if (logs.contains('Invalid argument')) {
            errorMessage = '오류: 잘못된 명령어 인수';
          } else if (logs.contains('Codec not found')) {
            errorMessage = '오류: 비디오 코덱을 찾을 수 없습니다';
          } else if (logs.contains('Unable to choose an output format')) {
            errorMessage = '오류: 출력 포맷을 결정할 수 없습니다';
          }
        }

        _processingStatusNotifier.value = errorMessage;
        debugPrint('FFmpeg 실패 - ReturnCode: $returnCode');
      }
    } catch (e) {
      debugPrint('FFmpeg 실행 오류: $e');
      _processingStatusNotifier.value = 'FFmpeg 실행 오류: $e';
    }
  }

  Future<void> _cleanupRawFrames() async {
    try {
      if (_sessionDirectory == null) return;

      final rawFiles = _sessionDirectory!
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.raw'))
          .toList();

      for (final file in rawFiles) {
        await file.delete();
      }

      debugPrint('Raw 프레임 파일 ${rawFiles.length}개 정리 완료');
    } catch (e) {
      debugPrint('Raw 프레임 파일 정리 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('테스트용 스크린 레코더'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 상태 정보 패널
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: _isRecordingNotifier,
                      builder: (context, isRecording, child) {
                        return Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isRecording ? Colors.red : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<bool>(
                      valueListenable: _isRecordingNotifier,
                      builder: (context, isRecording, child) {
                        return Text(
                          isRecording ? '녹화 중...' : '녹화 대기',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isRecording ? Colors.red : Colors.grey[600],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _frameCountNotifier,
                        builder: (context, frameCount, child) {
                          return Text('캡쳐된 프레임: $frameCount');
                        },
                      ),
                    ),
                    Expanded(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _actualFpsNotifier,
                        builder: (context, fps, child) {
                          return Text('실제 FPS: ${fps.toStringAsFixed(1)}');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ValueListenableBuilder<String>(
                  valueListenable: _lastSavedPathNotifier,
                  builder: (context, path, child) {
                    return Text(
                      '저장 경로: ${path.isEmpty ? "없음" : path}',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ],
            ),
          ),

          // 영상 처리 상태 패널
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: _isProcessingVideoNotifier,
                      builder: (context, isProcessing, child) {
                        return Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isProcessing ? Colors.orange : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '영상 처리 상태',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<String>(
                  valueListenable: _processingStatusNotifier,
                  builder: (context, status, child) {
                    return Text(
                      status.isEmpty ? '영상 생성 대기 중' : status,
                      style: const TextStyle(fontSize: 12),
                    );
                  },
                ),
                const SizedBox(height: 4),
                ValueListenableBuilder<String>(
                  valueListenable: _finalVideoPathNotifier,
                  builder: (context, videoPath, child) {
                    return Text(
                      '최종 영상: ${videoPath.isEmpty ? "없음" : videoPath}',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ],
            ),
          ),

          // 4x4 그리드 (캡쳐 대상)
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: RepaintBoundary(
                  key: _globalKey,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ValueListenableBuilder<List<int>>(
                      valueListenable: _filledButtonsNotifier,
                      builder: (context, filledButtons, child) {
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                          itemCount: 16,
                          itemBuilder: (context, index) {
                            final isFilled = filledButtons.contains(index);
                            return GridButton(
                              index: index,
                              isFilled: isFilled,
                              onPressed: () => _onButtonPressed(index),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 컨트롤 패널
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 첫 번째 줄: 녹화 관련 버튼들
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: _isRecordingNotifier,
                      builder: (context, isRecording, child) {
                        return ElevatedButton.icon(
                          onPressed: isRecording ? _stopCapture : _startCapture,
                          icon:
                              Icon(isRecording ? Icons.stop : Icons.play_arrow),
                          label: Text(isRecording ? '녹화 중지' : '녹화 시작'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isRecording ? Colors.red : Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        );
                      },
                    ),
                    ElevatedButton.icon(
                      onPressed: _clearGrid,
                      icon: const Icon(Icons.clear),
                      label: const Text('그리드 초기화'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 두 번째 줄: 영상 생성 버튼
                ValueListenableBuilder<bool>(
                  valueListenable: _isRecordingNotifier,
                  builder: (context, isRecording, child) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _isProcessingVideoNotifier,
                      builder: (context, isProcessing, child) {
                        final bool canComposeVideo = !isRecording &&
                            !isProcessing &&
                            _frameCountNotifier.value > 0;

                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: canComposeVideo ? _composeVideo : null,
                            icon: isProcessing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.video_library),
                            label: Text(
                              isProcessing ? '영상 생성 중...' : '캡쳐된 프레임으로 영상 생성',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  '💡 그리드 버튼을 클릭하여 상태를 변경하고 녹화 → 영상 생성 순서로 사용하세요!',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GridButton extends StatelessWidget {
  final int index;
  final bool isFilled;
  final VoidCallback onPressed;

  const GridButton({
    super.key,
    required this.index,
    required this.isFilled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: isFilled ? Colors.deepPurple : Colors.grey[200],
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            '$index',
            style: TextStyle(
              color: isFilled ? Colors.white : Colors.black54,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
