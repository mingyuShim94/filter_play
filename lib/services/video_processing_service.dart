import 'dart:io';
import 'dart:math';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/log.dart';
import 'package:ffmpeg_kit_flutter_new/session.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// 비디오 처리 결과를 담는 클래스
class VideoProcessingResult {
  final bool success;
  final String? outputPath;
  final VideoProcessingError? error;

  VideoProcessingResult({
    required this.success,
    this.outputPath,
    this.error,
  });
}

/// 상세한 비디오 처리 에러 정보를 담는 클래스
class VideoProcessingError {
  final String message;
  final String? returnCode;
  final String? returnCodeMeaning;
  final String inputPath;
  final String? outputPath;
  final String ffmpegCommand;
  final List<String> logs;
  final String? stackTrace;
  final Map<String, dynamic> fileInfo;
  final DateTime timestamp;
  final String? lastStatistics;

  VideoProcessingError({
    required this.message,
    this.returnCode,
    this.returnCodeMeaning,
    required this.inputPath,
    this.outputPath,
    required this.ffmpegCommand,
    required this.logs,
    this.stackTrace,
    required this.fileInfo,
    required this.timestamp,
    this.lastStatistics,
  });

  /// 에러 정보를 구조화된 문자열로 변환
  String toDetailedString() {
    final buffer = StringBuffer();
    buffer.writeln('=== 비디오 처리 에러 상세 정보 ===');
    buffer.writeln('시간: ${timestamp.toString()}');
    buffer.writeln('플랫폼: Android (Flutter)');
    buffer.writeln('');

    buffer.writeln('🚫 에러 메시지:');
    buffer.writeln(message);
    buffer.writeln('');

    if (returnCode != null) {
      buffer.writeln('📊 FFmpeg 리턴 코드: $returnCode');
      if (returnCodeMeaning != null) {
        buffer.writeln('📋 리턴 코드 의미: $returnCodeMeaning');
      }

      // 권한 문제 가능성 체크
      if (returnCode == '1' || returnCode == '4') {
        buffer.writeln('⚠️  권한 문제 의심: 안드로이드 파일 시스템 권한 확인 필요');
      }
      buffer.writeln('');
    }

    buffer.writeln('📁 파일 시스템 정보:');
    buffer.writeln('입력 파일: $inputPath');
    if (outputPath != null) {
      buffer.writeln('출력 파일: $outputPath');
    }

    // 파일 경로 분석
    if (inputPath.contains('/storage/emulated/0/')) {
      buffer.writeln('📱 입력 경로 타입: 외부 저장소 (Public)');
    } else if (inputPath.contains('/data/user/0/') ||
        inputPath.contains('/data/data/')) {
      buffer.writeln('📱 입력 경로 타입: 앱 내부 저장소 (Private)');
    }

    if (outputPath != null) {
      if (outputPath!.contains('/storage/emulated/0/')) {
        buffer.writeln('📱 출력 경로 타입: 외부 저장소 (Public)');
      } else if (outputPath!.contains('/data/user/0/') ||
          outputPath!.contains('/data/data/')) {
        buffer.writeln('📱 출력 경로 타입: 앱 내부 저장소 (Private)');
      }
    }

    fileInfo.forEach((key, value) {
      if (value is Map) {
        buffer.writeln('$key:');
        value.forEach((subKey, subValue) {
          buffer.writeln('  $subKey: $subValue');
        });
      } else {
        buffer.writeln('$key: $value');
      }
    });
    buffer.writeln('');

    buffer.writeln('⚙️ FFmpeg 명령어:');
    buffer.writeln(ffmpegCommand);
    buffer.writeln('');

    if (lastStatistics != null) {
      buffer.writeln('📈 마지막 통계:');
      buffer.writeln(lastStatistics);
      buffer.writeln('');
    }

    if (logs.isNotEmpty) {
      buffer.writeln('📜 처리 로그 (전체):');
      for (int i = 0; i < logs.length; i++) {
        buffer.writeln('${i + 1}. ${logs[i]}');
      }
      buffer.writeln('');
    }

    // 해결 방안 제안
    buffer.writeln('🔧 문제 해결 방안:');
    if (returnCode == '1' || returnCode == '4' || message.contains('권한')) {
      buffer.writeln('1. 저장소 권한 확인: 앱 설정에서 저장소 권한이 허용되어 있는지 확인');
      buffer.writeln('2. 파일 경로 확인: 앱이 해당 경로에 쓰기 권한을 가지고 있는지 확인');
      buffer.writeln('3. 외부 저장소 상태: SD카드가 마운트되어 있고 사용 가능한지 확인');
    }
    if (inputPath != outputPath &&
        inputPath.contains('/storage/') &&
        outputPath?.contains('/data/') == true) {
      buffer.writeln('4. 경로 불일치: 입력(외부)과 출력(내부) 경로가 다름 - 동일한 저장소 사용 권장');
    }
    buffer.writeln('5. 디버깅: `adb logcat | grep FFmpeg` 명령어로 더 자세한 로그 확인 가능');
    buffer.writeln('');

    if (stackTrace != null) {
      buffer.writeln('🔍 스택 트레이스:');
      buffer.writeln(stackTrace);
    }

    return buffer.toString();
  }
}

/// 최적의 출력 디렉토리 선택 결과
class _DirectorySelectionResult {
  final String directory;
  final List<String> logs;
  final String reason;

  _DirectorySelectionResult({
    required this.directory,
    required this.logs,
    required this.reason,
  });
}

/// 비디오 처리 서비스
class VideoProcessingService {
  /// 리턴 코드에 따른 의미 매핑
  static String _getReturnCodeMeaning(int? code) {
    if (code == null) return '알 수 없는 코드';

    switch (code) {
      case 0:
        return '성공';
      case 1:
        return '일반적인 오류';
      case 2:
        return '잘못된 인수';
      case 3:
        return '파일을 찾을 수 없음';
      case 4:
        return '권한 거부';
      case 5:
        return '메모리 부족';
      case 6:
        return '지원하지 않는 형식';
      case 250:
        return '사용자에 의한 취소';
      case 251:
        return 'FFmpeg 실행 실패';
      case 252:
        return '명령어 파싱 오류';
      case 253:
        return '세션 생성 실패';
      default:
        return 'FFmpeg 오류 (코드: $code)';
    }
  }

  /// 파일 정보 수집
  static Future<Map<String, dynamic>> _getFileInfo(String filePath) async {
    final info = <String, dynamic>{};

    try {
      final file = File(filePath);
      if (await file.exists()) {
        final stat = await file.stat();
        info['존재'] = true;
        info['크기'] = '${(stat.size / 1024 / 1024).toStringAsFixed(2)} MB';
        info['생성시간'] = stat.changed.toString();
        info['수정시간'] = stat.modified.toString();
        info['타입'] = stat.type.toString();
      } else {
        info['존재'] = false;
      }
    } catch (e) {
      info['파일정보오류'] = e.toString();
    }

    return info;
  }

  /// 디렉토리 쓰기 권한 확인
  static Future<bool> _canWriteToDirectory(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        return false;
      }

      // 테스트 파일을 생성해서 쓰기 권한 확인
      final testFile = File(path.join(directoryPath,
          'write_test_${DateTime.now().millisecondsSinceEpoch}.tmp'));
      await testFile.writeAsString('test');
      final canWrite = await testFile.exists();

      // 테스트 파일 삭제
      if (canWrite) {
        await testFile.delete();
      }

      return canWrite;
    } catch (e) {
      return false;
    }
  }

  /// 최적의 출력 디렉토리 선택
  static Future<_DirectorySelectionResult> _getBestOutputDirectory(
      String inputPath) async {
    final logs = <String>[];

    // 1순위: 입력 파일과 같은 디렉토리
    final inputFile = File(inputPath);
    final inputDirectory = inputFile.parent.path;
    logs.add('🔍 1순위: 입력 파일과 같은 디렉토리');
    logs.add('   경로: $inputDirectory');

    final inputDirWritable = await _canWriteToDirectory(inputDirectory);
    logs.add('   쓰기 권한: $inputDirWritable');

    if (inputDirWritable) {
      logs.add('   ✅ 선택됨: 입력 파일과 같은 디렉토리');
      return _DirectorySelectionResult(
        directory: inputDirectory,
        logs: logs,
        reason: '입력 파일과 같은 디렉토리 (권한 OK)',
      );
    }

    // 2순위: 외부 저장소 캐시 디렉토리
    logs.add('🔍 2순위: 외부 저장소 캐시 디렉토리');
    try {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final cacheDir = path.join(externalDir.path, 'cache');
        await Directory(cacheDir).create(recursive: true);
        logs.add('   경로: $cacheDir');

        final cacheDirWritable = await _canWriteToDirectory(cacheDir);
        logs.add('   쓰기 권한: $cacheDirWritable');

        if (cacheDirWritable) {
          logs.add('   ✅ 선택됨: 외부 저장소 캐시 디렉토리');
          return _DirectorySelectionResult(
            directory: cacheDir,
            logs: logs,
            reason: '외부 저장소 캐시 디렉토리 (권한 OK)',
          );
        }
      } else {
        logs.add('   ❌ 외부 저장소에 접근할 수 없음');
      }
    } catch (e) {
      logs.add('   ❌ 외부 저장소 접근 실패: $e');
    }

    // 3순위: 앱 내부 임시 디렉토리
    logs.add('🔍 3순위: 앱 내부 임시 디렉토리');
    final tempDir = await getTemporaryDirectory();
    logs.add('   경로: ${tempDir.path}');
    logs.add('   ⚠️ 선택됨: 임시 디렉토리 (최후 수단)');

    return _DirectorySelectionResult(
      directory: tempDir.path,
      logs: logs,
      reason: '앱 내부 임시 디렉토리 (최후 수단)',
    );
  }

  /// 원본 영상에서 카메라 프리뷰 영역(9:16 비율)만 크롭하는 메서드
  ///
  /// [inputPath] 원본 영상 파일 경로
  /// [screenWidth] Flutter 화면 너비 (픽셀)
  /// [screenHeight] Flutter 화면 높이 (픽셀)
  /// [cameraWidth] Flutter 카메라 영역 너비 (픽셀)
  /// [cameraHeight] Flutter 카메라 영역 높이 (픽셀)
  /// [leftOffset] Flutter 카메라 영역 왼쪽 오프셋 (픽셀)
  /// [topOffset] Flutter 카메라 영역 상단 오프셋 (픽셀)
  /// [progressCallback] 진행률 콜백 (선택적)
  ///
  /// Returns [VideoProcessingResult] 처리 결과
  static Future<VideoProcessingResult> cropVideoToCameraPreview({
    required String inputPath,
    required double screenWidth,
    required double screenHeight,
    required double cameraWidth,
    required double cameraHeight,
    required double leftOffset,
    required double topOffset,
    Function(double progress)? progressCallback,
  }) async {
    final logs = <String>[];
    String? lastStatistics;
    String? outputPath;

    try {
      // 최적의 출력 디렉토리 선택
      final dirResult = await _getBestOutputDirectory(inputPath);
      final outputDirectory = dirResult.directory;

      final fileName = path.basenameWithoutExtension(inputPath);
      final extension = path.extension(inputPath);
      outputPath = path.join(outputDirectory,
          '${fileName}_camera_preview_${DateTime.now().millisecondsSinceEpoch}$extension');

      // 입력 파일 정보 수집
      final inputFileInfo = await _getFileInfo(inputPath);

      // 디렉토리 선택 로그 추가
      logs.addAll(dirResult.logs);
      logs.add('');
      logs.add('🎯 최종 선택: ${dirResult.reason}');
      logs.add('📁 출력 파일 경로: $outputPath');
      logs.add('');

      // 디렉토리 권한 재확인
      final canWrite = await _canWriteToDirectory(outputDirectory);
      logs.add('✅ 출력 디렉토리 쓰기 권한 재확인: $canWrite');

      if (!canWrite) {
        final error = VideoProcessingError(
          message: '출력 디렉토리에 쓰기 권한이 없습니다: $outputDirectory',
          inputPath: inputPath,
          outputPath: outputPath,
          ffmpegCommand: '권한 확인 실패로 명령어 실행 불가',
          logs: logs,
          fileInfo: {
            '입력파일': inputFileInfo,
            '출력디렉토리': {'경로': outputDirectory, '쓰기권한': canWrite},
          },
          timestamp: DateTime.now(),
        );

        return VideoProcessingResult(success: false, error: error);
      }

      // Flutter 카메라 프리뷰 영역에 정확히 맞춘 크롭 계산
      // Flutter에서 계산된 실제 카메라 영역 좌표를 사용

      // Flutter 화면 좌표를 비디오 해상도 비율로 변환
      // 비디오 해상도는 실제 입력 비디오의 해상도를 사용
      // 화면 해상도와 비디오 해상도의 비율을 계산하여 정확한 크롭 영역 도출

      logs.add('📱 Flutter 화면 정보:');
      logs.add('   화면 크기: ${screenWidth.toInt()}x${screenHeight.toInt()}');
      logs.add('   카메라 영역: ${cameraWidth.toInt()}x${cameraHeight.toInt()}');
      logs.add('   오프셋: (${leftOffset.toInt()}, ${topOffset.toInt()})');
      logs.add('');

      // 비율 기반 크롭 파라미터 계산
      // crop=width:height:x:y 형식
      // Flutter 좌표를 비디오 해상도 비율로 변환
      final cropWidth =
          'trunc(iw*${(cameraWidth / screenWidth).toStringAsFixed(6)})';
      final cropHeight =
          'trunc(ih*${(cameraHeight / screenHeight).toStringAsFixed(6)})';
      final cropX =
          'trunc(iw*${(leftOffset / screenWidth).toStringAsFixed(6)})';
      final cropY =
          'trunc(ih*${(topOffset / screenHeight).toStringAsFixed(6)})';

      final command = '''
        -i "$inputPath" 
        -vf "crop=$cropWidth:$cropHeight:$cropX:$cropY" 
        -c:v libx264 -crf 15 -preset medium -r 46 -pix_fmt yuv420p
        -c:a copy "$outputPath"
      '''
          .replaceAll('\n', '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      logs.add('🎯 크롭 파라미터:');
      logs.add(
          '   Width: $cropWidth (${(cameraWidth / screenWidth * 100).toStringAsFixed(1)}%)');
      logs.add(
          '   Height: $cropHeight (${(cameraHeight / screenHeight * 100).toStringAsFixed(1)}%)');
      logs.add(
          '   X: $cropX (${(leftOffset / screenWidth * 100).toStringAsFixed(1)}%)');
      logs.add(
          '   Y: $cropY (${(topOffset / screenHeight * 100).toStringAsFixed(1)}%)');
      logs.add('');

      logs.add('⚙️ FFmpeg 명령어: $command');
      logs.add('📁 입력 파일: $inputPath');
      logs.add('📁 출력 파일: $outputPath');
      logs.add('🎯 크롭 방식: Flutter 카메라 프리뷰 영역 정확 매칭');
      logs.add('📐 크롭 계산: 화면 좌표 → 비디오 해상도 비율 변환');
      logs.add('🎬 화질 설정: H.264 CRF 15 (고화질), 46fps 유지, yuv420p');
      logs.add('🔊 오디오 설정: AAC 원본 복사 (재압축 없음)');

      // FFmpeg 실행
      final session = await FFmpegKit.executeAsync(
        command,
        (Session session) async {
          logs.add('세션 완료');
        },
        (Log log) {
          logs.add('[LOG] ${log.getMessage()}');
        },
        (Statistics statistics) {
          lastStatistics =
              'Frame: ${statistics.getVideoFrameNumber()}, Size: ${statistics.getSize()}, Time: ${statistics.getTime()}ms, Bitrate: ${statistics.getBitrate()}, Speed: ${statistics.getSpeed()}x';
          logs.add('[STATS] $lastStatistics');

          // 진행률 콜백 호출 (통계 기반으로 대략적 계산)
          progressCallback?.call(
              min(1.0, statistics.getTime() / 30000.0)); // 30초 기준으로 대략적 계산
        },
      );

      // 결과 확인
      final returnCode = await session.getReturnCode();
      final output = await session.getOutput();

      logs.add('세션 출력: $output');
      logs.add('리턴 코드: ${returnCode?.getValue()}');

      // FFmpeg 처리 후 파일 시스템 쓰기 완료를 위한 대기
      logs.add('파일 시스템 쓰기 대기 (500ms)...');
      await Future.delayed(Duration(milliseconds: 500));

      // null 리턴 코드 또는 성공 코드 처리
      bool isSuccess = false;

      if (returnCode == null) {
        // null 리턴 코드의 경우 로그에서 성공 패턴 확인
        logs.add('리턴 코드가 null - 로그에서 성공 패턴 검사 중...');
        final hasSuccessPattern = logs.any((log) =>
            log.contains('Lsize=') ||
            log.contains('video:') ||
            log.contains('bitrate=') ||
            log.contains('speed='));

        if (hasSuccessPattern) {
          logs.add('✅ 로그에서 성공 패턴 발견 - 처리 성공으로 판단');
          isSuccess = true;
        } else {
          logs.add('❌ 로그에서 성공 패턴 없음');
        }
      } else if (ReturnCode.isSuccess(returnCode)) {
        logs.add('✅ 리턴 코드 성공');
        isSuccess = true;
      }

      if (isSuccess) {
        // 파일 존재 확인 (재시도 로직 포함)
        bool fileExists = false;
        for (int attempt = 1; attempt <= 5; attempt++) {
          logs.add('출력 파일 존재 확인 (시도 $attempt/5)...');
          final outputFile = File(outputPath);
          fileExists = await outputFile.exists();

          if (fileExists) {
            logs.add('✅ 출력 파일 발견됨');
            break;
          } else {
            logs.add('❌ 출력 파일 없음 - 500ms 후 재시도');
            if (attempt < 5) {
              await Future.delayed(Duration(milliseconds: 500));
            }
          }
        }

        if (fileExists) {
          final outputFileInfo = await _getFileInfo(outputPath);
          logs.add('출력 파일 생성 성공: ${outputFileInfo['크기']}');

          // 파일 시스템 안정성을 위한 추가 대기
          logs.add('파일 시스템 안정화 대기 (1초)...');
          await Future.delayed(Duration(seconds: 1));

          progressCallback?.call(1.0); // 완료
          return VideoProcessingResult(
            success: true,
            outputPath: outputPath,
          );
        } else {
          // 성공으로 판단했지만 파일이 없는 경우
          final error = VideoProcessingError(
            message: 'FFmpeg 처리가 성공한 것으로 판단되지만 출력 파일이 생성되지 않았습니다. (타이밍 이슈 가능성)',
            returnCode: returnCode?.getValue().toString() ?? 'null',
            returnCodeMeaning: returnCode != null
                ? _getReturnCodeMeaning(returnCode.getValue())
                : '리턴 코드 없음',
            inputPath: inputPath,
            outputPath: outputPath,
            ffmpegCommand: command,
            logs: logs,
            fileInfo: {
              '입력파일': inputFileInfo,
              '출력파일': {'존재': false, '경로': outputPath},
            },
            timestamp: DateTime.now(),
            lastStatistics: lastStatistics,
          );

          return VideoProcessingResult(
            success: false,
            error: error,
          );
        }
      } else {
        // FFmpeg 실패 - 상세한 진단 정보 포함
        String detailedMessage = 'FFmpeg 카메라 프리뷰 영역 추출이 실패했습니다.';

        // 로그에서 일반적인 오류 패턴 검사
        final hasInvalidDimensions = logs.any((log) =>
            log.contains('Invalid dimensions') ||
            log.contains('width not divisible by 2') ||
            log.contains('height not divisible by 2'));

        final hasCodecError = logs.any((log) =>
            log.contains('codec') ||
            log.contains('encoder') ||
            log.contains('libx264'));

        final hasCropError = logs.any((log) =>
            log.contains('crop') ||
            log.contains('Invalid crop') ||
            log.contains('out of bounds'));

        if (hasInvalidDimensions) {
          detailedMessage +=
              ' [해상도 오류: 가로/세로 크기가 2로 나누어지지 않음 - Android 호환성 문제]';
        } else if (hasCodecError) {
          detailedMessage += ' [코덱 오류: H.264 인코딩 문제 - ExoPlayer 호환성 이슈]';
        } else if (hasCropError) {
          detailedMessage += ' [크롭 오류: 9:16 비율 계산 문제 또는 영역 초과]';
        }

        final error = VideoProcessingError(
          message: detailedMessage,
          returnCode: returnCode?.getValue().toString(),
          returnCodeMeaning: _getReturnCodeMeaning(returnCode?.getValue()),
          inputPath: inputPath,
          outputPath: outputPath,
          ffmpegCommand: command,
          logs: logs,
          fileInfo: {
            '입력파일': inputFileInfo,
            '출력파일': await _getFileInfo(outputPath),
          },
          timestamp: DateTime.now(),
          lastStatistics: lastStatistics,
        );

        return VideoProcessingResult(
          success: false,
          error: error,
        );
      }
    } catch (e, stackTrace) {
      // 예외 발생
      final inputFileInfo = await _getFileInfo(inputPath);
      final outputFileInfo = outputPath != null
          ? await _getFileInfo(outputPath)
          : <String, dynamic>{};

      final error = VideoProcessingError(
        message: '카메라 프리뷰 영역 추출 중 예외가 발생했습니다: ${e.toString()}',
        inputPath: inputPath,
        outputPath: outputPath,
        ffmpegCommand: '명령어 생성 실패',
        logs: logs,
        stackTrace: stackTrace.toString(),
        fileInfo: {
          '입력파일': inputFileInfo,
          '출력파일': outputFileInfo,
        },
        timestamp: DateTime.now(),
        lastStatistics: lastStatistics,
      );

      return VideoProcessingResult(
        success: false,
        error: error,
      );
    }
  }
}
