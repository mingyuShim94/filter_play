import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import 'sample_animation.dart';

void main() {
  runApp(const ScreenRecordTestApp());
}

class ScreenRecordTestApp extends StatelessWidget {
  const ScreenRecordTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Screen Record Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const ScreenRecordTestScreen(),
    );
  }
}

class ScreenRecordTestScreen extends StatefulWidget {
  const ScreenRecordTestScreen({super.key});

  @override
  State<ScreenRecordTestScreen> createState() => _ScreenRecordTestScreenState();
}

class _ScreenRecordTestScreenState extends State<ScreenRecordTestScreen> {
  // RepaintBoundary를 참조하기 위한 GlobalKey
  final GlobalKey _captureKey = GlobalKey();

  // 상태 변수들
  bool _isRecording = false;
  bool _isProcessing = false;
  String _statusText = '녹화 준비됨';

  // 녹화 관련 변수들
  Timer? _frameCaptureTimer;
  final AudioRecorder _audioRecorder = AudioRecorder();
  Directory? _sessionDirectory;
  int _frameCount = 0;

  @override
  void dispose() {
    _frameCaptureTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('화면 녹화 테스트'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 상태 표시
            Container(
              width: double.infinity,
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
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isRecording) ...[
                    Text(
                      '프레임: $_frameCount',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),

            // 녹화할 영역 (RepaintBoundary로 감싸기)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _isRecording ? Colors.red : Colors.grey,
                    width: _isRecording ? 3 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: RepaintBoundary(
                    key: _captureKey,
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.white,
                      child: const Center(
                        child: SampleAnimation(),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 컨트롤 버튼들
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isRecording || _isProcessing
                          ? null
                          : _startRecording,
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: const Text('녹화 시작'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isRecording ? _stopRecording : null,
                      icon: const Icon(Icons.stop, size: 20),
                      label: const Text('녹화 중지'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 권한 확인 및 요청
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

      // Android에서는 임시 디렉토리만 사용하므로 추가 저장소 권한 불필요
      // 최종 파일은 앱 내부 Documents 디렉토리에 저장됨
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

  // 녹화 시작
  Future<void> _startRecording() async {
    // 권한 확인
    if (!await _checkPermissions()) return;

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

      // 오디오 녹음 시작
      final audioPath = '${_sessionDirectory!.path}/audio.m4a';
      await _audioRecorder.start(const RecordConfig(), path: audioPath);

      // 프레임 캡처 시작 (24fps)
      _frameCaptureTimer = Timer.periodic(
        Duration(milliseconds: (1000 / 24).round()),
        (timer) => _captureFrame(),
      );
    } catch (e) {
      setState(() {
        _isRecording = false;
        _statusText = '녹화 시작 실패: $e';
      });
    }
  }

  // 프레임 캡처
  Future<void> _captureFrame() async {
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

        setState(() {
          _frameCount++;
        });
      }
    } catch (e) {
      print('프레임 캡처 오류: $e');
    }
  }

  // 녹화 중지
  Future<void> _stopRecording() async {
    setState(() {
      _isRecording = false;
      _isProcessing = true;
      _statusText = '동영상 처리 중...';
    });

    try {
      // 타이머 중지
      _frameCaptureTimer?.cancel();

      // 오디오 녹음 중지
      await _audioRecorder.stop();

      // FFmpeg로 동영상 합성
      await _composeVideo();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusText = '녹화 중지 실패: $e';
      });
    }
  }

  // FFmpeg를 사용한 동영상 합성
  Future<void> _composeVideo() async {
    try {
      // 출력 파일 경로
      final documentsDir = await getApplicationDocumentsDirectory();
      final outputPath =
          '${documentsDir.path}/screen_record_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // FFmpeg 명령어 구성
      final framePath = '${_sessionDirectory!.path}/frame_%05d.png';
      final audioPath = '${_sessionDirectory!.path}/audio.m4a';

      final command =
          '-framerate 24 -i "$framePath" -i "$audioPath" -c:v libx264 -c:a aac -pix_fmt yuv420p -shortest "$outputPath"';

      // FFmpeg 실행
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        // 성공적으로 완료
        await _cleanupTempFiles();
        setState(() {
          _isProcessing = false;
          _statusText = '녹화 완료! 저장됨: ${outputPath.split('/').last}';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('동영상이 저장되었습니다: $outputPath'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        throw Exception('FFmpeg 실행 실패');
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusText = '동영상 합성 실패: $e';
      });
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
}
