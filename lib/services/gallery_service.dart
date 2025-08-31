import 'dart:io';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as path;

/// 갤러리 저장 결과를 담는 클래스
class GallerySaveResult {
  final bool success;
  final String? message;
  final GalException? error;

  GallerySaveResult({
    required this.success,
    this.message,
    this.error,
  });
}

/// 갤러리 저장 진행률 콜백 타입
typedef ProgressCallback = void Function(double progress, String status);

/// 갤러리 저장 서비스
class GalleryService {
  /// 비디오를 갤러리에 저장
  /// 
  /// [filePath] 저장할 비디오 파일 경로
  /// [albumName] 저장할 앨범명 (기본값: 'FilterPlay')
  /// [progressCallback] 진행률 콜백 (선택적)
  /// 
  /// Returns [GallerySaveResult] 저장 결과
  static Future<GallerySaveResult> saveVideoToGallery({
    required String filePath,
    String albumName = 'FilterPlay',
    ProgressCallback? progressCallback,
  }) async {
    try {
      // 파일 존재 여부 확인
      final file = File(filePath);
      if (!await file.exists()) {
        return GallerySaveResult(
          success: false,
          message: '저장할 파일을 찾을 수 없습니다: $filePath',
        );
      }

      // 진행률 초기화
      progressCallback?.call(0.1, '권한 확인 중...');

      // 권한 확인 및 요청
      bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        progressCallback?.call(0.2, '권한 요청 중...');
        hasAccess = await Gal.requestAccess();
        if (!hasAccess) {
          return GallerySaveResult(
            success: false,
            message: '갤러리 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요.',
          );
        }
      }

      // 진행률 업데이트
      progressCallback?.call(0.5, '갤러리에 저장 중...');

      // 갤러리에 저장 (FilterPlay 앨범에)
      await Gal.putVideo(filePath, album: albumName);

      // 완료
      progressCallback?.call(1.0, '저장 완료');

      return GallerySaveResult(
        success: true,
        message: '갤러리에 저장되었습니다',
      );

    } on GalException catch (e) {
      String message = switch (e.type) {
        GalExceptionType.accessDenied => '갤러리 접근 권한이 거부되었습니다',
        GalExceptionType.notEnoughSpace => '저장 공간이 부족합니다',
        GalExceptionType.notSupportedFormat => '지원하지 않는 파일 형식입니다',
        GalExceptionType.unexpected => '예상치 못한 오류가 발생했습니다',
      };

      progressCallback?.call(0.0, '저장 실패');

      return GallerySaveResult(
        success: false,
        message: message,
        error: e,
      );

    } catch (e) {
      progressCallback?.call(0.0, '저장 실패');

      return GallerySaveResult(
        success: false,
        message: '저장 중 오류가 발생했습니다: ${e.toString()}',
      );
    }
  }

  /// 권한 상태 확인
  static Future<bool> hasGalleryAccess() async {
    try {
      return await Gal.hasAccess();
    } catch (e) {
      return false;
    }
  }

  /// 권한 요청
  static Future<bool> requestGalleryAccess() async {
    try {
      return await Gal.requestAccess();
    } catch (e) {
      return false;
    }
  }

  /// 갤러리 앱 열기
  static Future<void> openGallery() async {
    try {
      await Gal.open();
    } catch (e) {
      // 갤러리 열기 실패시 무시 (선택적 기능)
    }
  }

  /// 파일명에서 확장자를 포함한 안전한 파일명 생성
  static String generateSafeFileName(String originalPath, String prefix) {
    final extension = path.extension(originalPath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${prefix}_$timestamp$extension';
  }

  /// 파일 크기를 사람이 읽기 쉬운 형식으로 변환
  static Future<String> getFileSizeFormatted(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final size = await file.length();
        if (size < 1024) {
          return '${size}B';
        } else if (size < 1024 * 1024) {
          return '${(size / 1024).toStringAsFixed(1)}KB';
        } else {
          return '${(size / 1024 / 1024).toStringAsFixed(1)}MB';
        }
      }
      return '알 수 없음';
    } catch (e) {
      return '알 수 없음';
    }
  }
}