import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/captured_frame.dart';
import '../widgets/debug_log_overlay.dart';

/// 알파 비디오 인코딩 서비스 (Task 2)
/// PNG 시퀀스를 VP9+alpha WebM으로 인코딩
class AlphaVideoEncodingService {
  static const String _tag = 'AlphaVideoEncodingService';

  /// PNG 시퀀스를 VP9+alpha WebM으로 인코딩
  /// [frames] 인코딩할 프레임 목록
  /// [outputPath] 출력 WebM 파일 경로
  /// [fps] 프레임레이트 (기본: 24fps)
  /// [bitrateKbps] 비트레이트 (기본: 2000kbps)
  /// [onProgress] 진행률 콜백 (0.0-1.0)
  static Future<String?> encodeToWebM({
    required List<CapturedFrame> frames,
    required String outputPath,
    int fps = 24,
    int bitrateKbps = 2000,
    void Function(double progress)? onProgress,
  }) async {
    if (frames.isEmpty) {
      if (kDebugMode) print('$_tag: 인코딩할 프레임이 없습니다');
      return null;
    }

    try {
      if (kDebugMode) {
        print('$_tag: =====PNG 시퀀스 → WebM VP9+alpha 인코딩 시작=====');
        print('$_tag: 프레임 수: ${frames.length}');
        print('$_tag: FPS: $fps');
        print('$_tag: 비트레이트: ${bitrateKbps}kbps');
        print('$_tag: 출력: $outputPath');
      }
      DebugLogger.instance.info('WebM 인코딩 시작 (${frames.length}프레임)');

      // 출력 디렉토리 생성
      final outputDir = Directory(path.dirname(outputPath));
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
        if (kDebugMode) print('$_tag: 출력 디렉토리 생성됨: ${outputDir.path}');
      }

      // 첫 번째 프레임으로 해상도 확인
      final firstFrame = frames.first;
      final width = firstFrame.width;
      final height = firstFrame.height;

      if (kDebugMode) {
        print('$_tag: 해상도: ${width}x$height');
        print('$_tag: 첫 프레임: ${firstFrame.filePath}');
      }

      // 프레임 파일들 실제 존재 확인
      final frameDir = path.dirname(frames.first.filePath);
      if (kDebugMode) print('$_tag: 프레임 디렉토리: $frameDir');
      
      // 실제 프레임 파일들 확인
      final frameFiles = <String>[];
      for (int i = 0; i < frames.length; i++) {
        final frameFile = File(frames[i].filePath);
        if (await frameFile.exists()) {
          frameFiles.add(frames[i].filePath);
          if (kDebugMode && i < 3) {
            final fileSize = await frameFile.length();
            print('$_tag: 프레임 ${i}: ${frames[i].filePath} (${fileSize} bytes)');
          }
        } else {
          if (kDebugMode) print('$_tag: ❌ 누락된 프레임: ${frames[i].filePath}');
        }
      }
      
      if (frameFiles.isEmpty) {
        if (kDebugMode) print('$_tag: ❌ 유효한 프레임 파일이 없습니다');
        DebugLogger.instance.error('유효한 프레임 파일이 없음');
        return null;
      }
      
      if (kDebugMode) print('$_tag: 유효한 프레임 파일: ${frameFiles.length}/${frames.length}');

      // 프레임 경로 패턴 생성 (ffmpeg -i 용)
      final inputPattern = path.join(frameDir, 'overlay_%06d.png');
      if (kDebugMode) print('$_tag: 입력 패턴: $inputPattern');

      // FFmpeg 명령어 구성 (안드로이드 최적화)
      // 먼저 VP9 시도, 실패시 H.264+alpha 대안 사용
      List<String> command;
      
      // VP9 인코딩 시도 (1차)
      command = [
        '-y', // 파일 덮어쓰기
        '-loglevel', 'verbose', // 상세 로그 레벨
        '-f', 'image2', // 입력 포맷 명시
        '-framerate', fps.toString(), // 입력 프레임레이트
        '-i', inputPattern, // 입력 패턴
        '-c:v', 'libvpx-vp9', // VP9 코덱
        '-pix_fmt', 'yuva420p', // 알파 채널 포함 픽셀 포맷
        '-b:v', '${bitrateKbps}k', // 비트레이트
        '-crf', '30', // 품질 설정 (VP9에서 안정적)
        '-speed', '8', // 빠른 인코딩 (모바일 최적화)
        '-auto-alt-ref', '0', // 자동 참조 프레임 비활성화
        '-lag-in-frames', '0', // 지연 없음
        '-error-resilient', '1', // 에러 복원력
        '-threads', '1', // 단일 스레드 (안정성)
        '-f', 'webm', // 출력 포맷 명시
        outputPath,
      ];

      final commandString = 'ffmpeg ${command.join(' ')}';
      if (kDebugMode) {
        print('$_tag: =====FFmpeg 명령어=====');
        print('$_tag: $commandString');
        print('$_tag: ==========================');
      }

      // 진행률 추적을 위한 변수
      var lastProgress = 0.0;

      // FFmpeg 실행 (1차: VP9 시도)
      var session = await FFmpegKit.execute(commandString);
      var returnCode = await session.getReturnCode();

      // VP9 실패시 H.264+알파 채널 대안 시도
      if (!ReturnCode.isSuccess(returnCode)) {
        if (kDebugMode) {
          print('$_tag: VP9 인코딩 실패, H.264 대안으로 재시도...');
          final logs = await session.getAllLogsAsString();
          if (logs != null && logs.isNotEmpty) {
            final truncatedLog = logs.length > 200 ? logs.substring(logs.length - 200) : logs;
            print('$_tag: VP9 실패 이유: $truncatedLog');
          }
        }
        DebugLogger.instance.warning('VP9 실패, H.264 대안 시도');
        
        // H.264 대안 명령어 (MOV 컨테이너 + ProRes 4444)
        final h264OutputPath = outputPath.replaceAll('.webm', '.mov');
        final fallbackCommand = [
          '-y',
          '-loglevel', 'verbose',
          '-f', 'image2',
          '-framerate', fps.toString(),
          '-i', inputPattern,
          '-c:v', 'prores_ks', // ProRes 4444 (알파 채널 지원)
          '-profile:v', '4444', // 4444 프로파일 (알파 포함)
          '-pix_fmt', 'yuva444p10le', // 알파 포함 픽셀 포맷
          '-f', 'mov', // MOV 컨테이너
          h264OutputPath,
        ];
        
        final fallbackCommandString = 'ffmpeg ${fallbackCommand.join(' ')}';
        if (kDebugMode) {
          print('$_tag: =====H.264 대안 명령어=====');
          print('$_tag: $fallbackCommandString');
          print('$_tag: ===========================');
        }
        
        session = await FFmpegKit.execute(fallbackCommandString);
        returnCode = await session.getReturnCode();
        
        if (ReturnCode.isSuccess(returnCode)) {
          // H.264 성공시 경로 업데이트
          outputPath = h264OutputPath;
          if (kDebugMode) print('$_tag: H.264 대안 인코딩 성공');
          DebugLogger.instance.success('H.264 대안 인코딩 성공');
        }
      }

      // 진행률 시뮬레이션 (FFmpeg 진행률 파싱은 복잡하므로 간단히 처리)
      final totalSteps = 100;
      for (int i = 0; i <= totalSteps; i++) {
        final progress = i / totalSteps;
        if (progress - lastProgress >= 0.1) { // 10%씩 업데이트
          onProgress?.call(progress);
          lastProgress = progress;
          if (kDebugMode && i % 20 == 0) {
            print('$_tag: 진행률: ${(progress * 100).toInt()}%');
          }
        }
        await Future.delayed(const Duration(milliseconds: 10));
      }

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          final fileSize = await outputFile.length();
          final fileSizeMB = fileSize / (1024 * 1024);
          
          if (kDebugMode) {
            print('$_tag: ✅ WebM 인코딩 성공');
            print('$_tag: 파일 크기: ${fileSizeMB.toStringAsFixed(1)}MB');
            print('$_tag: 출력 파일: $outputPath');
          }
          DebugLogger.instance.success('WebM 인코딩 성공 (${fileSizeMB.toStringAsFixed(1)}MB)');
          
          onProgress?.call(1.0); // 완료
          return outputPath;
        } else {
          if (kDebugMode) print('$_tag: ❌ 출력 파일이 생성되지 않았습니다');
          DebugLogger.instance.error('출력 파일이 생성되지 않음');
          return null;
        }
      } else {
        // 상세한 에러 로그 출력
        final logs = await session.getLogs();
        final allLogs = await session.getAllLogsAsString();
        
        DebugLogger.instance.error('FFmpeg 인코딩 실패 (코드: $returnCode)');
        
        if (kDebugMode) {
          print('$_tag: ❌ FFmpeg 인코딩 실패 (코드: $returnCode)');
          print('$_tag: =====FFmpeg 에러 로그 (상위 10개)=====');
          
          int logCount = 0;
          for (final log in logs) {
            if (logCount >= 10) break;
            final message = log.getMessage();
            if (message.isNotEmpty) {
              print('$_tag: LOG: $message');
              logCount++;
            }
          }
          
          print('$_tag: =====전체 로그 (마지막 500자)=====');
          if (allLogs != null && allLogs.isNotEmpty) {
            final truncatedLog = allLogs.length > 500 
              ? allLogs.substring(allLogs.length - 500)
              : allLogs;
            print('$_tag: $truncatedLog');
          }
          print('$_tag: ================================');
        }
        return null;
      }

    } catch (e) {
      if (kDebugMode) print('$_tag: ❌ 인코딩 중 예외 발생: $e');
      return null;
    }
  }

  /// 프레임 파일들이 연속적인지 확인하고 누락된 프레임 보정
  /// [frames] 확인할 프레임 목록
  static Future<List<CapturedFrame>> validateFrameSequence(
      List<CapturedFrame> frames) async {
    if (frames.isEmpty) return frames;

    final sortedFrames = List<CapturedFrame>.from(frames)
      ..sort((a, b) => a.frameNumber.compareTo(b.frameNumber));

    final validatedFrames = <CapturedFrame>[];
    CapturedFrame? lastFrame;

    for (int i = 0; i < sortedFrames.length; i++) {
      final currentFrame = sortedFrames[i];
      
      // 첫 번째 프레임이거나 연속적인 경우
      if (lastFrame == null || 
          currentFrame.frameNumber == lastFrame.frameNumber + 1) {
        validatedFrames.add(currentFrame);
      } else {
        // 프레임 누락 감지 - 이전 프레임으로 채우기
        final missingCount = currentFrame.frameNumber - lastFrame.frameNumber - 1;
        if (kDebugMode) {
          print('$_tag: 프레임 누락 감지: ${lastFrame.frameNumber + 1} ~ ${currentFrame.frameNumber - 1} (${missingCount}개)');
        }
        
        // 누락된 프레임들을 마지막 유효 프레임으로 채움
        for (int j = 1; j <= missingCount; j++) {
          final fillFrame = CapturedFrame(
            filePath: lastFrame.filePath, // 이전 프레임 재사용
            timestamp: lastFrame.timestamp + (j * (1.0 / 24)), // 추정 타임스탬프
            frameNumber: lastFrame.frameNumber + j,
            capturedAt: lastFrame.capturedAt,
            width: lastFrame.width,
            height: lastFrame.height,
          );
          validatedFrames.add(fillFrame);
        }
        
        validatedFrames.add(currentFrame);
      }
      
      lastFrame = currentFrame;
    }

    if (kDebugMode && validatedFrames.length != frames.length) {
      print('$_tag: 프레임 보정 완료: ${frames.length} → ${validatedFrames.length}');
    }

    return validatedFrames;
  }

  /// WebM 파일 정보 확인
  /// [webmPath] 확인할 WebM 파일 경로
  static Future<Map<String, dynamic>?> getWebMInfo(String webmPath) async {
    try {
      final file = File(webmPath);
      if (!await file.exists()) {
        return null;
      }

      // ffprobe로 파일 정보 조회
      final session = await FFmpegKit.execute(
        'ffprobe -v quiet -print_format json -show_format -show_streams "$webmPath"'
      );
      
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        final output = await session.getOutput();
        if (kDebugMode) print('$_tag: WebM 정보 조회 성공');
        
        return {
          'exists': true,
          'size': await file.length(),
          'path': webmPath,
          'probe_output': output,
        };
      } else {
        if (kDebugMode) print('$_tag: WebM 정보 조회 실패');
        return null;
      }
    } catch (e) {
      if (kDebugMode) print('$_tag: WebM 정보 조회 중 오류: $e');
      return null;
    }
  }

  /// 인코딩 설정 최적화 (디바이스 성능에 따라)
  static Map<String, dynamic> getOptimizedSettings({
    required int frameCount,
    required int width,
    required int height,
  }) {
    // 기본 설정
    var fps = 24;
    var bitrateKbps = 2000;
    var speed = 5;

    // 해상도에 따른 최적화
    final pixels = width * height;
    if (pixels > 1920 * 1080) {
      // 4K 이상
      bitrateKbps = 4000;
      speed = 6;
    } else if (pixels > 1280 * 720) {
      // 1080p
      bitrateKbps = 2500;
      speed = 5;
    } else {
      // 720p 이하
      bitrateKbps = 1500;
      speed = 4;
    }

    // 프레임 수에 따른 최적화
    if (frameCount > 300) { // 12초 이상 (24fps 기준)
      fps = 20; // 프레임률 약간 낮춤
      bitrateKbps = (bitrateKbps * 0.8).round(); // 비트레이트 20% 감소
    }

    return {
      'fps': fps,
      'bitrateKbps': bitrateKbps,
      'speed': speed,
      'estimated_size_mb': (frameCount * bitrateKbps / 8 / 1024 / fps).toStringAsFixed(1),
    };
  }
}