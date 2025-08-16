import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// 비디오 내보내기 서비스
/// 
/// 연속된 프레임 이미지를 MP4 비디오로 변환하는 기능을 제공합니다.
class VideoExportService {
  /// 프레임을 MP4로 변환
  /// 
  /// [framesDirectory] 프레임 이미지들이 저장된 디렉토리 경로
  /// [frameCount] 총 프레임 수
  /// [outputPath] 출력 파일 경로 (null인 경우 자동 생성)
  /// [onProgress] 진행률 콜백 (0.0 ~ 1.0)
  /// [onLog] 로그 메시지 콜백
  /// 
  /// Returns: 성공 시 출력 파일 경로, 실패 시 null
  static Future<String?> convertFramesToMp4({
    required String framesDirectory,
    required int frameCount,
    String? outputPath,
    Function(double progress)? onProgress,
    Function(String message)? onLog,
  }) async {
    try {
      // 출력 경로가 지정되지 않은 경우 자동 생성
      if (outputPath == null) {
        final documentsDir = await getApplicationDocumentsDirectory();
        final videosDir = Directory('${documentsDir.path}/videos');
        if (!videosDir.existsSync()) {
          await videosDir.create(recursive: true);
        }
        
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        outputPath = '${videosDir.path}/video_$timestamp.mp4';
      }

      // 프레임 파일 존재 확인
      final frameDir = Directory(framesDirectory);
      if (!frameDir.existsSync()) {
        onLog?.call('프레임 디렉토리가 존재하지 않습니다: $framesDirectory');
        return null;
      }

      // 첫 번째 프레임 파일 확인
      final firstFrame = File('$framesDirectory/frame_00001.png');
      if (!firstFrame.existsSync()) {
        onLog?.call('첫 번째 프레임 파일이 존재하지 않습니다: ${firstFrame.path}');
        return null;
      }

      onLog?.call('비디오 변환 시작 - $frameCount 프레임 → MP4');

      // FFmpeg 명령어 생성 (성공 사례와 동일한 패턴)
      final command = _buildFFmpegCommand(framesDirectory, outputPath, frameCount);
      
      onLog?.call('FFmpeg 명령어: $command');

      // FFmpeg 실행 (성공 사례와 동일한 동기 방식)
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      final output = await session.getOutput();

      if (ReturnCode.isSuccess(returnCode)) {
        onLog?.call('✅ 비디오 변환 완료: $outputPath');
      } else if (ReturnCode.isCancel(returnCode)) {
        onLog?.call('❌ 비디오 변환 취소됨');
        return null;
      } else {
        onLog?.call('❌ 비디오 변환 실패 (코드: $returnCode)');
        onLog?.call('출력: $output');
        return null;
      }

      // 출력 파일 존재 확인
      final outputFile = File(outputPath);
      if (!outputFile.existsSync()) {
        onLog?.call('❌ 출력 파일이 생성되지 않았습니다: $outputPath');
        return null;
      }

      final fileSizeKB = (outputFile.lengthSync() / 1024).round();
      onLog?.call('✅ 비디오 생성 완료: ${outputFile.path} ($fileSizeKB KB)');

      return outputPath;
      
    } catch (e) {
      onLog?.call('❌ 비디오 변환 중 오류 발생: $e');
      return null;
    }
  }

  /// FFmpeg 명령어 생성 (성공 사례와 동일한 패턴)
  static String _buildFFmpegCommand(String framesDirectory, String outputPath, int frameCount) {
    // 성공 사례와 동일한 단순한 명령어 구조
    // 파일 경로를 따옴표로 감싸서 특수문자/공백 문제 해결
    final framePath = "$framesDirectory/frame_%05d.png";
    
    return '-framerate 24 -i "$framePath" -c:v libx264 -pix_fmt yuv420p "$outputPath"';
  }


  /// 진행 중인 변환 작업 취소
  static Future<void> cancelConversion() async {
    await FFmpegKit.cancel();
  }

  /// 3-1단계: 기본 비디오만 변환 테스트
  /// 
  /// [framesDirectory] 프레임 이미지들이 있는 디렉토리
  /// [frameCount] 총 프레임 수
  /// [actualDuration] 실제 녹화 시간 (초)
  /// [outputPath] 출력 MP4 파일 경로 (선택사항)
  /// [onLog] 로그 메시지 콜백
  /// Returns: 성공 시 출력 파일 경로, 실패 시 null
  static Future<String?> testStep1BasicVideo({
    required String framesDirectory,
    required int frameCount,
    double? actualDuration,
    String? outputPath,
    Function(String message)? onLog,
  }) async {
    try {
      // 프레임 디렉토리 존재 확인
      final frameDir = Directory(framesDirectory);
      if (!frameDir.existsSync()) {
        onLog?.call('❌ 프레임 디렉토리가 존재하지 않습니다: $framesDirectory');
        return null;
      }

      // 첫 번째 프레임 파일 확인
      final firstFrame = File('$framesDirectory/frame_00001.png');
      if (!firstFrame.existsSync()) {
        onLog?.call('❌ 첫 번째 프레임 파일이 존재하지 않습니다: ${firstFrame.path}');
        return null;
      }

      // 출력 파일 경로 설정
      outputPath ??= await _generateOutputPath('step1_basic_video');

      // 출력 디렉토리 생성 확인
      final outputFile = File(outputPath);
      final outputDir = outputFile.parent;
      if (!outputDir.existsSync()) {
        await outputDir.create(recursive: true);
      }

      // 프레임 이미지 경로 패턴 (성공 사례와 동일)
      final framePath = '$framesDirectory/frame_%05d.png';

      // 프레임 파일 시퀀스 검증
      final frameValidation = await _validateFrameSequence(framesDirectory, frameCount, onLog);
      if (!frameValidation.isValid) {
        onLog?.call('❌ 프레임 시퀀스 검증 실패: ${frameValidation.errorMessage}');
        return null;
      }
      
      // 실제 사용할 프레임 수 업데이트
      final actualFrameCount = frameValidation.validFrameCount;

      // 동적 프레임레이트 계산
      double calculatedFramerate = 24.0;  // 기본값
      if (actualDuration != null && actualDuration > 0) {
        calculatedFramerate = actualFrameCount / actualDuration;
        // 일반적인 프레임레이트 범위로 제한 (1-60fps)
        calculatedFramerate = calculatedFramerate.clamp(1.0, 60.0);
      }

      // FFmpeg 명령어 구성 (동적 프레임레이트 + H264 짝수 차원 요구사항 + 프레임 시퀀스 최적화)
      final command = '-framerate $calculatedFramerate -i "$framePath" -vf "crop=trunc(iw/2)*2:trunc(ih/2)*2" -c:v libx264 -pix_fmt yuv420p -avoid_negative_ts make_zero "$outputPath"';

      onLog?.call('🎬 3-1단계: 기본 비디오만 변환 테스트 시작');
      onLog?.call('프레임 경로: $framePath');
      onLog?.call('출력 경로: $outputPath'); 
      onLog?.call('요청 프레임 수: $frameCount개 / 실제 유효: $actualFrameCount개');
      if (actualDuration != null) {
        onLog?.call('실제 녹화 시간: ${actualDuration.toStringAsFixed(2)}초');
        onLog?.call('계산된 프레임레이트: ${calculatedFramerate.toStringAsFixed(2)}fps');
      } else {
        onLog?.call('기본 프레임레이트: ${calculatedFramerate.toStringAsFixed(2)}fps');
      }
      onLog?.call('차원 처리: H264 호환을 위해 짝수 차원으로 자동 크롭');
      onLog?.call('FFmpeg 명령어: $command');

      // FFmpeg 실행
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      final output = await session.getOutput();

      if (ReturnCode.isSuccess(returnCode)) {
        if (outputFile.existsSync()) {
          final fileSizeKB = (outputFile.lengthSync() / 1024).round();
          onLog?.call('✅ 3-1단계 완료: $outputPath ($fileSizeKB KB)');
          return outputPath;
        } else {
          onLog?.call('❌ 출력 파일이 생성되지 않았습니다: $outputPath');
        }
      } else if (ReturnCode.isCancel(returnCode)) {
        onLog?.call('❌ FFmpeg 실행이 취소되었습니다');
      } else {
        onLog?.call('❌ FFmpeg 실행 실패 (코드: $returnCode)');
        onLog?.call('FFmpeg 출력: $output');
      }
      
      return null;
    } catch (e) {
      onLog?.call('❌ 3-1단계 오류: $e');
      return null;
    }
  }

  /// 3-2단계: 비디오 품질 최적화 테스트
  /// 
  /// [framesDirectory] 프레임 이미지들이 있는 디렉토리
  /// [frameCount] 총 프레임 수
  /// [crf] 품질 설정 (18=최고품질, 23=기본, 28=고압축)
  /// [preset] 인코딩 속도 (fast/medium/slow)
  /// [outputPath] 출력 MP4 파일 경로 (선택사항)
  /// [onLog] 로그 메시지 콜백
  /// Returns: 성공 시 출력 파일 경로, 실패 시 null
  static Future<String?> testStep2OptimizedVideo({
    required String framesDirectory,
    required int frameCount,
    int crf = 23,
    String preset = 'medium',
    String? outputPath,
    Function(String message)? onLog,
  }) async {
    try {
      // 프레임 디렉토리 존재 확인
      final frameDir = Directory(framesDirectory);
      if (!frameDir.existsSync()) {
        onLog?.call('❌ 프레임 디렉토리가 존재하지 않습니다: $framesDirectory');
        return null;
      }

      // 첫 번째 프레임 파일 확인
      final firstFrame = File('$framesDirectory/frame_00001.png');
      if (!firstFrame.existsSync()) {
        onLog?.call('❌ 첫 번째 프레임 파일이 존재하지 않습니다: ${firstFrame.path}');
        return null;
      }

      // 출력 파일 경로 설정
      outputPath ??= await _generateOutputPath('step2_optimized_video');

      // 출력 디렉토리 생성 확인
      final outputFile = File(outputPath);
      final outputDir = outputFile.parent;
      if (!outputDir.existsSync()) {
        await outputDir.create(recursive: true);
      }

      // 프레임 이미지 경로 패턴
      final framePath = '$framesDirectory/frame_%05d.png';

      // FFmpeg 명령어 구성 (성공 사례 기반 품질 최적화 + H264 짝수 차원 요구사항)
      final command = '-framerate 24 -i "$framePath" -vf "crop=trunc(iw/2)*2:trunc(ih/2)*2" -c:v libx264 -preset $preset -crf $crf -pix_fmt yuv420p "$outputPath"';

      onLog?.call('🎯 3-2단계: 비디오 품질 최적화 테스트 시작');
      onLog?.call('프레임 경로: $framePath');
      onLog?.call('출력 경로: $outputPath');
      onLog?.call('프레임 수: $frameCount개');
      onLog?.call('품질 설정: CRF=$crf, Preset=$preset');
      onLog?.call('차원 처리: H264 호환을 위해 짝수 차원으로 자동 크롭');
      onLog?.call('FFmpeg 명령어: $command');

      // FFmpeg 실행
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      final output = await session.getOutput();

      if (ReturnCode.isSuccess(returnCode)) {
        if (outputFile.existsSync()) {
          final fileSizeKB = (outputFile.lengthSync() / 1024).round();
          onLog?.call('✅ 3-2단계 완료: $outputPath ($fileSizeKB KB)');
          return outputPath;
        } else {
          onLog?.call('❌ 출력 파일이 생성되지 않았습니다: $outputPath');
        }
      } else if (ReturnCode.isCancel(returnCode)) {
        onLog?.call('❌ FFmpeg 실행이 취소되었습니다');
      } else {
        onLog?.call('❌ FFmpeg 실행 실패 (코드: $returnCode)');
        onLog?.call('FFmpeg 출력: $output');
      }
      
      return null;
    } catch (e) {
      onLog?.call('❌ 3-2단계 오류: $e');
      return null;
    }
  }

  /// 3-3단계: 오디오 통합 최종 테스트
  /// 
  /// [framesDirectory] 프레임 이미지들이 있는 디렉토리
  /// [audioPath] 오디오 파일 경로
  /// [frameCount] 총 프레임 수
  /// [outputPath] 출력 MP4 파일 경로 (선택사항)
  /// [onLog] 로그 메시지 콜백
  /// Returns: 성공 시 출력 파일 경로, 실패 시 null
  static Future<String?> testStep3VideoWithAudio({
    required String framesDirectory,
    required String audioPath,
    required int frameCount,
    String? outputPath,
    Function(String message)? onLog,
  }) async {
    try {
      // 프레임 디렉토리 존재 확인
      final frameDir = Directory(framesDirectory);
      if (!frameDir.existsSync()) {
        onLog?.call('❌ 프레임 디렉토리가 존재하지 않습니다: $framesDirectory');
        return null;
      }

      // 첫 번째 프레임 파일 확인
      final firstFrame = File('$framesDirectory/frame_00001.png');
      if (!firstFrame.existsSync()) {
        onLog?.call('❌ 첫 번째 프레임 파일이 존재하지 않습니다: ${firstFrame.path}');
        return null;
      }

      // 오디오 파일 존재 확인
      final audioFile = File(audioPath);
      if (!audioFile.existsSync()) {
        onLog?.call('❌ 오디오 파일이 존재하지 않습니다: $audioPath');
        return null;
      }

      // 출력 파일 경로 설정
      outputPath ??= await _generateOutputPath('step3_video_with_audio');

      // 출력 디렉토리 생성 확인
      final outputFile = File(outputPath);
      final outputDir = outputFile.parent;
      if (!outputDir.existsSync()) {
        await outputDir.create(recursive: true);
      }

      // 프레임 이미지 경로 패턴
      final framePath = '$framesDirectory/frame_%05d.png';

      // FFmpeg 명령어 구성 (성공 사례 기반 + H264 짝수 차원 요구사항)
      final command = '-framerate 24 -i "$framePath" -i "$audioPath" -vf "crop=trunc(iw/2)*2:trunc(ih/2)*2" -c:v libx264 -c:a aac -pix_fmt yuv420p -shortest "$outputPath"';

      onLog?.call('🎵 3-3단계: 오디오 통합 최종 테스트 시작');
      onLog?.call('프레임 경로: $framePath');
      onLog?.call('오디오 경로: $audioPath');
      onLog?.call('출력 경로: $outputPath');
      onLog?.call('프레임 수: $frameCount개');
      onLog?.call('차원 처리: H264 호환을 위해 짝수 차원으로 자동 크롭');
      onLog?.call('FFmpeg 명령어: $command');

      // FFmpeg 실행
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      final output = await session.getOutput();

      if (ReturnCode.isSuccess(returnCode)) {
        if (outputFile.existsSync()) {
          final fileSizeKB = (outputFile.lengthSync() / 1024).round();
          onLog?.call('✅ 3-3단계 완료: $outputPath ($fileSizeKB KB)');
          return outputPath;
        } else {
          onLog?.call('❌ 출력 파일이 생성되지 않았습니다: $outputPath');
        }
      } else if (ReturnCode.isCancel(returnCode)) {
        onLog?.call('❌ FFmpeg 실행이 취소되었습니다');
      } else {
        onLog?.call('❌ FFmpeg 실행 실패 (코드: $returnCode)');
        onLog?.call('FFmpeg 출력: $output');
      }
      
      return null;
    } catch (e) {
      onLog?.call('❌ 3-3단계 오류: $e');
      return null;
    }
  }

  /// 프레임 파일 시퀀스 검증
  /// 
  /// [framesDirectory] 프레임 파일들이 있는 디렉토리
  /// [expectedFrameCount] 예상 프레임 수
  /// [onLog] 로그 메시지 콜백
  /// Returns: 검증 결과와 실제 유효한 프레임 수
  static Future<FrameValidationResult> _validateFrameSequence(
    String framesDirectory, 
    int expectedFrameCount, 
    Function(String message)? onLog
  ) async {
    try {
      final frameDir = Directory(framesDirectory);
      if (!frameDir.existsSync()) {
        return FrameValidationResult(
          isValid: false,
          errorMessage: '프레임 디렉토리가 존재하지 않음',
          validFrameCount: 0,
        );
      }

      // 실제 저장된 프레임 파일들 스캔
      final frameFiles = <int>[];
      final files = frameDir.listSync().whereType<File>();
      
      for (final file in files) {
        final fileName = file.path.split('/').last;
        final match = RegExp(r'frame_(\d{5})\.png').firstMatch(fileName);
        if (match != null) {
          final frameNumber = int.parse(match.group(1)!);
          frameFiles.add(frameNumber);
        }
      }

      frameFiles.sort();
      
      onLog?.call('📋 프레임 파일 스캔 결과: ${frameFiles.length}개 발견');
      onLog?.call('📋 프레임 번호 범위: ${frameFiles.isEmpty ? "없음" : "${frameFiles.first} ~ ${frameFiles.last}"}');

      if (frameFiles.isEmpty) {
        return FrameValidationResult(
          isValid: false,
          errorMessage: '프레임 파일이 하나도 없음',
          validFrameCount: 0,
        );
      }

      // 연속성 검사
      final missingFrames = <int>[];
      for (int i = frameFiles.first; i <= frameFiles.last; i++) {
        if (!frameFiles.contains(i)) {
          missingFrames.add(i);
        }
      }

      if (missingFrames.isNotEmpty) {
        onLog?.call('⚠️ 누락된 프레임: ${missingFrames.take(10).join(", ")}${missingFrames.length > 10 ? "... (총 ${missingFrames.length}개)" : ""}');
      }

      // 검증 결과
      final isValid = frameFiles.isNotEmpty;
      final validFrameCount = frameFiles.length;
      
      if (validFrameCount != expectedFrameCount) {
        onLog?.call('⚠️ 프레임 수 불일치: 예상 $expectedFrameCount개 / 실제 $validFrameCount개');
      }

      return FrameValidationResult(
        isValid: isValid,
        errorMessage: isValid ? '' : '유효한 프레임이 없음',
        validFrameCount: validFrameCount,
        missingFrames: missingFrames,
      );
      
    } catch (e) {
      return FrameValidationResult(
        isValid: false,
        errorMessage: '프레임 검증 중 오류: $e',
        validFrameCount: 0,
      );
    }
  }

  /// 오디오 녹음 기능을 위한 AudioRecorder 래퍼
  static Future<AudioRecorder> createAudioRecorder() async {
    return AudioRecorder();
  }

  /// 출력 파일 경로 생성
  /// 
  /// [prefix] 파일명 접두사
  /// Returns: 생성된 파일 경로
  static Future<String> _generateOutputPath(String prefix) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${documentsDir.path}/${prefix}_$timestamp.mp4';
  }

  /// 임시 파일들 정리
  static Future<void> cleanupTempFiles(String tempDirectory, {Function(String)? onLog}) async {
    try {
      final tempDir = Directory(tempDirectory);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
        onLog?.call('임시 파일 정리 완료: $tempDirectory');
      }
    } catch (e) {
      // 정리 실패는 무시 (로그만 출력)
      onLog?.call('임시 파일 정리 실패: $e');
    }
  }
}

/// 프레임 검증 결과 클래스
class FrameValidationResult {
  final bool isValid;
  final String errorMessage;
  final int validFrameCount;
  final List<int> missingFrames;

  FrameValidationResult({
    required this.isValid,
    required this.errorMessage,
    required this.validFrameCount,
    this.missingFrames = const [],
  });
}