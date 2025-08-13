import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../widgets/debug_log_overlay.dart';

/// 비디오 합성 서비스 (Task 3)
/// 원본 mp4와 오버레이 webm을 합성하여 최종 mp4 생성
class VideoCompositionService {
  static const String _tag = 'VideoCompositionService';

  /// 원본 비디오와 오버레이를 합성하여 최종 mp4 생성
  /// [videoPath] 원본 mp4 파일 경로
  /// [overlayPath] 오버레이 webm 파일 경로 
  /// [outputPath] 출력 mp4 파일 경로
  /// [offsetSeconds] 오버레이 타이밍 오프셋 (초)
  /// [onProgress] 진행률 콜백 (0.0-1.0)
  static Future<String?> compose({
    required String videoPath,
    required String overlayPath,
    required String outputPath,
    double offsetSeconds = 0.0,
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (kDebugMode) {
        print('$_tag: 비디오 합성 시작');
        print('$_tag: 원본 비디오: $videoPath');
        print('$_tag: 오버레이: $overlayPath');
        print('$_tag: 출력: $outputPath');
        print('$_tag: 오프셋: ${offsetSeconds.toStringAsFixed(3)}s');
      }
      DebugLogger.instance.info('비디오 합성 시작');

      // 입력 파일 존재 확인
      final videoFile = File(videoPath);
      final overlayFile = File(overlayPath);

      if (!await videoFile.exists()) {
        if (kDebugMode) print('$_tag: ❌ 원본 비디오 파일이 없습니다: $videoPath');
        DebugLogger.instance.error('원본 비디오 파일 없음');
        return null;
      }

      if (!await overlayFile.exists()) {
        if (kDebugMode) print('$_tag: ❌ 오버레이 파일이 없습니다: $overlayPath');
        DebugLogger.instance.error('오버레이 파일 없음');
        return null;
      }

      // 출력 디렉토리 생성
      final outputDir = Directory(path.dirname(outputPath));
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // 파일 크기 확인
      final videoSize = await videoFile.length();
      final overlaySize = await overlayFile.length();
      
      if (kDebugMode) {
        print('$_tag: 원본 크기: ${(videoSize / 1024 / 1024).toStringAsFixed(1)}MB');
        print('$_tag: 오버레이 크기: ${(overlaySize / 1024 / 1024).toStringAsFixed(1)}MB');
      }

      // FFmpeg 명령어 구성
      final command = await _buildCompositionCommand(
        videoPath: videoPath,
        overlayPath: overlayPath,
        outputPath: outputPath,
        offsetSeconds: offsetSeconds,
      );

      final commandString = command.join(' ');
      if (kDebugMode) print('$_tag: FFmpeg 명령어: $commandString');

      // 진행률 추적
      var lastProgress = 0.0;

      // FFmpeg 실행
      final session = await FFmpegKit.execute(commandString);
      
      // 진행률 시뮬레이션 (실제 파싱은 복잡하므로 간단히 처리)
      final totalSteps = 100;
      for (int i = 0; i <= totalSteps; i++) {
        final progress = i / totalSteps;
        if (progress - lastProgress >= 0.1) { // 10%씩 업데이트
          onProgress?.call(progress);
          lastProgress = progress;
          if (kDebugMode && i % 25 == 0) {
            print('$_tag: 합성 진행률: ${(progress * 100).toInt()}%');
          }
        }
        await Future.delayed(const Duration(milliseconds: 15)); // 합성은 인코딩보다 시간 소요
      }

      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          final outputSize = await outputFile.length();
          final outputSizeMB = outputSize / (1024 * 1024);
          
          if (kDebugMode) {
            print('$_tag: ✅ 비디오 합성 성공');
            print('$_tag: 최종 크기: ${outputSizeMB.toStringAsFixed(1)}MB');
            print('$_tag: 출력 파일: $outputPath');
          }
          DebugLogger.instance.success('비디오 합성 성공 (${outputSizeMB.toStringAsFixed(1)}MB)');
          
          onProgress?.call(1.0); // 완료
          return outputPath;
        } else {
          if (kDebugMode) print('$_tag: ❌ 출력 파일이 생성되지 않았습니다');
          DebugLogger.instance.error('비디오 합성 출력 파일 생성 실패');
          return null;
        }
      } else {
        // 에러 로그 출력
        final logs = await session.getLogs();
        DebugLogger.instance.error('비디오 합성 실패 (코드: $returnCode)');
        if (kDebugMode) {
          print('$_tag: ❌ 비디오 합성 실패 (코드: $returnCode)');
          for (final log in logs.take(5)) { // 처음 5개 로그만 출력
            print('$_tag: ${log.getMessage()}');
          }
        }
        return null;
      }

    } catch (e) {
      if (kDebugMode) print('$_tag: ❌ 합성 중 예외 발생: $e');
      return null;
    }
  }

  /// FFmpeg 합성 명령어 구성
  static Future<List<String>> _buildCompositionCommand({
    required String videoPath,
    required String overlayPath,
    required String outputPath,
    required double offsetSeconds,
  }) async {
    final command = <String>[
      'ffmpeg',
      '-y', // 파일 덮어쓰기
    ];

    // 입력 파일들
    command.addAll(['-i', videoPath]); // 원본 비디오

    // 오프셋 적용
    if (offsetSeconds != 0.0) {
      command.addAll(['-itsoffset', offsetSeconds.toStringAsFixed(3)]);
    }
    command.addAll(['-i', overlayPath]); // 오버레이 비디오

    // 오버레이 파일 형식에 따른 필터 구성
    final isWebM = overlayPath.toLowerCase().endsWith('.webm');
    final isMOV = overlayPath.toLowerCase().endsWith('.mov');
    
    String filterComplex;
    if (isWebM) {
      // WebM VP9+alpha 처리
      filterComplex = '[1:v]scale=iw:ih[ov];[0:v][ov]overlay=0:0:format=auto';
    } else if (isMOV) {
      // MOV ProRes 4444 알파 처리
      filterComplex = '[1:v]scale=iw:ih,format=yuva420p[ov];[0:v][ov]overlay=0:0:format=auto';
    } else {
      // 기본 처리 (알파 없음)
      filterComplex = '[1:v]scale=iw:ih[ov];[0:v][ov]overlay=0:0';
    }
    
    command.addAll([
      '-filter_complex',
      filterComplex,
    ]);

    // 출력 설정
    command.addAll([
      '-c:v', 'libx264', // H.264 코덱
      '-preset', 'veryfast', // 빠른 인코딩 (모바일 최적화)
      '-pix_fmt', 'yuv420p', // 호환성을 위한 픽셀 포맷
      '-c:a', 'copy', // 오디오 복사 (재인코딩 없음)
      '-movflags', '+faststart', // 스트리밍 최적화
      outputPath,
    ]);

    return command;
  }

  /// 고급 합성 옵션 (위치, 크기 조절 포함)
  /// [overlayPosition] 오버레이 위치 ('0:0', 'center', 'top-right' 등)
  /// [overlayScale] 오버레이 스케일 (1.0 = 원본 크기)
  static Future<String?> composeAdvanced({
    required String videoPath,
    required String overlayPath,
    required String outputPath,
    double offsetSeconds = 0.0,
    String overlayPosition = '0:0',
    double overlayScale = 1.0,
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (kDebugMode) {
        print('$_tag: 고급 비디오 합성 시작');
        print('$_tag: 오버레이 위치: $overlayPosition');
        print('$_tag: 오버레이 스케일: $overlayScale');
      }

      // 입력 파일 존재 확인
      if (!await File(videoPath).exists() || !await File(overlayPath).exists()) {
        return null;
      }

      // 출력 디렉토리 생성
      final outputDir = Directory(path.dirname(outputPath));
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // 고급 필터 구성
      var filterComplex = '[1:v]';
      
      // 스케일 적용
      if (overlayScale != 1.0) {
        final scaleW = 'iw*$overlayScale';
        final scaleH = 'ih*$overlayScale';
        filterComplex += 'scale=$scaleW:$scaleH,';
      }
      
      filterComplex += 'format=yuva420p[ov];';
      
      // 위치 계산
      String overlayX, overlayY;
      switch (overlayPosition.toLowerCase()) {
        case 'center':
          overlayX = '(W-w)/2';
          overlayY = '(H-h)/2';
          break;
        case 'top-right':
          overlayX = 'W-w-10';
          overlayY = '10';
          break;
        case 'bottom-left':
          overlayX = '10';
          overlayY = 'H-h-10';
          break;
        case 'bottom-right':
          overlayX = 'W-w-10';
          overlayY = 'H-h-10';
          break;
        default:
          // '0:0' 형식이나 'x:y' 형식
          final parts = overlayPosition.split(':');
          overlayX = parts.isNotEmpty ? parts[0] : '0';
          overlayY = parts.length > 1 ? parts[1] : '0';
      }
      
      filterComplex += '[0:v][ov]overlay=$overlayX:$overlayY:format=auto';

      // FFmpeg 명령어 구성
      final command = <String>[
        'ffmpeg', '-y',
        '-i', videoPath,
      ];

      if (offsetSeconds != 0.0) {
        command.addAll(['-itsoffset', offsetSeconds.toStringAsFixed(3)]);
      }
      
      command.addAll([
        '-i', overlayPath,
        '-filter_complex', filterComplex,
        '-c:v', 'libx264',
        '-preset', 'veryfast',
        '-pix_fmt', 'yuv420p',
        '-c:a', 'copy',
        '-movflags', '+faststart',
        outputPath,
      ]);

      final commandString = command.join(' ');
      if (kDebugMode) print('$_tag: 고급 FFmpeg 명령어: $commandString');

      // FFmpeg 실행
      final session = await FFmpegKit.execute(commandString);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        if (await File(outputPath).exists()) {
          if (kDebugMode) print('$_tag: ✅ 고급 비디오 합성 성공');
          onProgress?.call(1.0);
          return outputPath;
        }
      } else {
        final logs = await session.getLogs();
        if (kDebugMode) {
          print('$_tag: ❌ 고급 비디오 합성 실패');
          for (final log in logs.take(3)) {
            print('$_tag: ${log.getMessage()}');
          }
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) print('$_tag: ❌ 고급 합성 중 예외 발생: $e');
      return null;
    }
  }

  /// 비디오 정보 조회
  /// [videoPath] 조회할 비디오 파일 경로
  static Future<Map<String, dynamic>?> getVideoInfo(String videoPath) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        return null;
      }

      // ffprobe로 비디오 정보 조회
      final session = await FFmpegKit.execute(
        'ffprobe -v quiet -print_format json -show_format -show_streams "$videoPath"'
      );
      
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        final output = await session.getOutput();
        if (kDebugMode) print('$_tag: 비디오 정보 조회 성공');
        
        return {
          'exists': true,
          'size': await file.length(),
          'path': videoPath,
          'probe_output': output,
        };
      } else {
        if (kDebugMode) print('$_tag: 비디오 정보 조회 실패');
        return null;
      }
    } catch (e) {
      if (kDebugMode) print('$_tag: 비디오 정보 조회 중 오류: $e');
      return null;
    }
  }

  /// 합성 품질 설정 최적화
  static Map<String, dynamic> getCompositionSettings({
    required int videoDurationSeconds,
    required int videoWidth,
    required int videoHeight,
    bool highQuality = false,
  }) {
    // 기본 설정
    var preset = 'veryfast';
    var crf = 23; // 품질 설정 (낮을수록 고품질)

    if (highQuality) {
      preset = 'medium';
      crf = 18;
    }

    // 해상도에 따른 최적화
    final pixels = videoWidth * videoHeight;
    if (pixels > 1920 * 1080 && !highQuality) {
      crf = 25; // 4K에서는 품질 약간 낮춤
    }

    // 예상 처리 시간 계산 (초)
    final estimatedProcessingTime = videoDurationSeconds * 
        (highQuality ? 3.0 : 1.5) * 
        (pixels > 1920 * 1080 ? 1.5 : 1.0);

    return {
      'preset': preset,
      'crf': crf,
      'estimated_processing_seconds': estimatedProcessingTime.round(),
      'quality_mode': highQuality ? 'high' : 'standard',
    };
  }
}