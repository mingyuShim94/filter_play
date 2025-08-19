import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// 이마 위치에 3D 사각형을 그리기 위한 데이터 클래스
class ForeheadRectangle {
  /// 이마 중심점 (화면 좌표)
  final Point<double> center;
  
  /// 사각형 너비
  final double width;
  
  /// 사각형 높이
  final double height;
  
  /// Y축 회전각 (좌우 방향, -180도 ~ 180도)
  final double rotationY;
  
  /// Z축 회전각 (기울기, -180도 ~ 180도)
  final double rotationZ;
  
  /// 얼굴과의 거리 비례 스케일 (1.0이 기본)
  final double scale;
  
  /// 사각형이 유효한지 여부
  final bool isValid;
  
  /// 애니메이션을 위한 시간 정보 (생성 시점)
  final DateTime timestamp;
  
  /// 텍스처로 사용할 이미지 (선택사항)
  final ui.Image? textureImage;

  ForeheadRectangle({
    required this.center,
    required this.width,
    required this.height,
    required this.rotationY,
    required this.rotationZ,
    required this.scale,
    this.isValid = true,
    DateTime? timestamp,
    this.textureImage,
  }) : timestamp = timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
  
  /// 현재 시간으로 ForeheadRectangle 생성
  ForeheadRectangle.withCurrentTime({
    required Point<double> center,
    required double width,
    required double height,
    required double rotationY,
    required double rotationZ,
    required double scale,
    bool isValid = true,
    ui.Image? textureImage,
  }) : this(
         center: center,
         width: width,
         height: height,
         rotationY: rotationY,
         rotationZ: rotationZ,
         scale: scale,
         isValid: isValid,
         timestamp: DateTime.now(),
         textureImage: textureImage,
       );

  /// 빈 사각형 생성 (유효하지 않음)
  ForeheadRectangle.empty()
      : center = const Point(0.0, 0.0),
        width = 0.0,
        height = 0.0,
        rotationY = 0.0,
        rotationZ = 0.0,
        scale = 1.0,
        isValid = false,
        timestamp = DateTime.fromMillisecondsSinceEpoch(0),
        textureImage = null;

  @override
  String toString() {
    return 'ForeheadRectangle(center: $center, size: ${width}x$height, '
        'rotY: ${rotationY.toStringAsFixed(1)}°, '
        'rotZ: ${rotationZ.toStringAsFixed(1)}°, '
        'scale: ${scale.toStringAsFixed(2)}, valid: $isValid)';
  }
}

/// 이마 위치 사각형 계산 및 관리 서비스
class ForeheadRectangleService {
  // 이마 위치 계산을 위한 비율 상수들 (안정적인 위치)
  static const double _foreheadYOffset = 0.45; // 눈 위로 얼굴 높이의 45% (더 위쪽 위치, 눈 안가림)
  static const double _foreheadWidthRatio = 0.25; // 얼굴 너비의 25% (더 작은 정사각형)
  static const double _foreheadHeightRatio = 0.25; // 얼굴 높이의 25% (정사각형 비율 유지)
  
  // 이미지 캐싱 (다중 이미지 지원)
  static final Map<String, ui.Image> _cachedTextureImages = {};
  static final Set<String> _loadingImages = {};
  static const int _maxCacheSize = 15; // 최대 캐시 크기
  
  // 스케일 계산을 위한 기준값들
  static const double _baseFaceSize = 200.0; // 기준 얼굴 크기 (픽셀)
  static const double _minScale = 0.5; // 최소 스케일
  static const double _maxScale = 2.0; // 최대 스케일
  
  // 각도 제한값들 (더 안정적인 변형)
  static const double _maxRotationY = 30.0; // Y축 회전 최대값 (도) - 더 부드럽게
  static const double _maxRotationZ = 20.0; // Z축 회전 최대값 (도) - 더 부드럽게
  
  /// 특정 경로의 텍스처 이미지 로딩 (비동기, 캐싱됨)
  static Future<ui.Image?> loadTextureImage(String? imagePath) async {
    // 이미지 경로가 없으면 null 반환
    if (imagePath == null || imagePath.isEmpty) {
      return null;
    }

    // 이미 캐싱된 이미지가 있으면 반환
    if (_cachedTextureImages.containsKey(imagePath)) {
      return _cachedTextureImages[imagePath];
    }
    
    // 이미 로딩 중이면 대기
    if (_loadingImages.contains(imagePath)) {
      // 간단한 폴링으로 로딩 완료 대기 (최대 5초)
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!_loadingImages.contains(imagePath) && _cachedTextureImages.containsKey(imagePath)) {
          return _cachedTextureImages[imagePath];
        }
      }
      return null;
    }
    
    try {
      _loadingImages.add(imagePath);
      
      // 캐시 크기 체크 및 정리
      if (_cachedTextureImages.length >= _maxCacheSize) {
        _clearOldestCacheEntries();
      }
      
      // 이미지 데이터 로딩 (파일 시스템 또는 assets)
      Uint8List bytes;
      if (File(imagePath).existsSync()) {
        // 로컬 파일에서 로딩
        bytes = await File(imagePath).readAsBytes();
      } else {
        // Assets에서 로딩
        final ByteData data = await rootBundle.load(imagePath);
        bytes = data.buffer.asUint8List();
      }
      
      // ui.Image로 디코딩
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      
      _cachedTextureImages[imagePath] = frameInfo.image;
      
      if (kDebugMode) {
        print('텍스처 이미지 로딩 완료: $imagePath (${frameInfo.image.width}x${frameInfo.image.height})');
      }
      
      return _cachedTextureImages[imagePath];
      
    } catch (e) {
      if (kDebugMode) {
        print('텍스처 이미지 로딩 실패: $imagePath - $e');
      }
      return null;
    } finally {
      _loadingImages.remove(imagePath);
    }
  }

  /// 가장 오래된 캐시 항목들 정리
  static void _clearOldestCacheEntries() {
    if (_cachedTextureImages.length > _maxCacheSize ~/ 2) {
      final keys = _cachedTextureImages.keys.toList();
      final keysToRemove = keys.take(_maxCacheSize ~/ 4).toList(); // 1/4 정도 제거
      
      for (final key in keysToRemove) {
        _cachedTextureImages[key]?.dispose();
        _cachedTextureImages.remove(key);
      }
      
      if (kDebugMode) {
        print('이미지 캐시 정리: ${keysToRemove.length}개 항목 제거');
      }
    }
  }
  
  /// 캐싱된 텍스처 이미지 해제
  static void disposeTextureImage() {
    for (final image in _cachedTextureImages.values) {
      image.dispose();
    }
    _cachedTextureImages.clear();
    _loadingImages.clear();
  }

  /// 얼굴 데이터로부터 이마 사각형 정보를 계산
  static Future<ForeheadRectangle?> calculateForeheadRectangle(Face face, CameraController controller, {String? imagePath}) async {
    try {
      // 필수 랜드마크 확인
      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];
      final noseBase = face.landmarks[FaceLandmarkType.noseBase];
      
      if (leftEye == null || rightEye == null || noseBase == null) {
        if (kDebugMode) {
          print('ForeheadRectangle: 필수 랜드마크가 누락됨');
        }
        return null;
      }

      // 두 눈의 중심점 계산
      final eyeCenter = Point<double>(
        (leftEye.position.x + rightEye.position.x) / 2.0,
        (leftEye.position.y + rightEye.position.y) / 2.0,
      );
      
      // 얼굴 bounding box에서 크기 정보 추출
      final faceRect = face.boundingBox;
      final faceWidth = faceRect.width;
      final faceHeight = faceRect.height;
      
      // 이마 중심점 계산 (눈 중심에서 위로 오프셋)
      final foreheadCenter = Point<double>(
        eyeCenter.x,
        eyeCenter.y - (faceHeight * _foreheadYOffset),
      );
      
      // 사각형 크기 계산
      final rectWidth = faceWidth * _foreheadWidthRatio;
      final rectHeight = faceHeight * _foreheadHeightRatio;
      
      // 얼굴 크기 기반 스케일 계산
      final avgFaceSize = (faceWidth + faceHeight) / 2.0;
      final scale = _calculateScale(avgFaceSize);
      
      // 회전각 처리 - 디바이스 센서 orientation 보정 적용
      final rawRotY = face.headEulerAngleY ?? 0.0;
      final rawRotZ = face.headEulerAngleZ ?? 0.0;
      
      // 센서 orientation에 따른 보정된 각도 계산
      final correctedRotY = _correctForDeviceOrientation(rawRotY, controller.description.sensorOrientation);
      final correctedRotZ = _correctForDeviceOrientation(rawRotZ, controller.description.sensorOrientation);
      
      final rotY = _clampRotation(correctedRotY, _maxRotationY);
      final rotZ = _clampRotation(correctedRotZ, _maxRotationZ);
      
      // 텍스처 이미지 로딩 (비동기이지만 캐싱되어 있다면 즉시 반환)
      ui.Image? textureImage;
      try {
        textureImage = await loadTextureImage(imagePath);
      } catch (e) {
        if (kDebugMode) {
          print('텍스처 이미지 로딩 중 오류: $e');
        }
        textureImage = null;
      }
      
      final result = ForeheadRectangle.withCurrentTime(
        center: foreheadCenter,
        width: rectWidth,
        height: rectHeight,
        rotationY: rotY,
        rotationZ: rotZ,
        scale: scale,
        isValid: true,
        textureImage: textureImage,
      );
      
      if (kDebugMode) {
        _debugPrintCalculation(face, eyeCenter, result);
      }
      
      return result;
      
    } catch (e) {
      if (kDebugMode) {
        print('ForeheadRectangle 계산 오류: $e');
      }
      return null;
    }
  }
  
  /// 얼굴 크기 기반 스케일 계산
  static double _calculateScale(double faceSize) {
    final ratio = faceSize / _baseFaceSize;
    return ratio.clamp(_minScale, _maxScale);
  }
  
  /// 회전각을 지정된 범위로 제한
  static double _clampRotation(double angle, double maxAngle) {
    return angle.clamp(-maxAngle, maxAngle);
  }
  
  /// 디바이스 센서 orientation에 따른 각도 보정
  /// 목표: 디바이스 회전과 관계없이 순수한 얼굴 회전만 반영
  static double _correctForDeviceOrientation(double angle, int sensorOrientation) {
    // 센서 orientation에 따른 보정
    // 0도: 세로 모드 (보정 없음)
    // 90도: 왼쪽으로 90도 회전
    // 180도: 거꾸로
    // 270도: 오른쪽으로 90도 회전
    switch (sensorOrientation) {
      case 0:
        return angle; // 세로 모드, 보정 없음
      case 90:
        return angle; // 현재는 단순 보정, 필요시 추가 조정
      case 180:
        return -angle; // 180도 회전시 각도 반전
      case 270:
        return angle; // 현재는 단순 보정, 필요시 추가 조정
      default:
        return angle; // 기본값
    }
  }
  
  /// 디버깅용 계산 정보 출력
  static void _debugPrintCalculation(
      Face face, Point<double> eyeCenter, ForeheadRectangle result) {
    print('=== ForeheadRectangle 계산 결과 ===');
    print('Face BoundingBox: ${face.boundingBox}');
    print('EyeCenter: $eyeCenter');
    print('Result: $result');
    print('HeadEulerAngleY: ${face.headEulerAngleY}');
    print('HeadEulerAngleZ: ${face.headEulerAngleZ}');
  }
  
  /// 이마 사각형 정보 출력 (디버깅용)
  static void printForeheadRectangle(ForeheadRectangle? rectangle) {
    if (!kDebugMode) return;
    
    if (rectangle != null && rectangle.isValid) {
      print('ForeheadRectangle: ${rectangle.toString()}');
    } else {
      print('ForeheadRectangle: Invalid or null');
    }
  }
  
  /// 두 이마 사각형 간의 변화량 계산 (애니메이션용)
  static ForeheadRectangle interpolate(
      ForeheadRectangle from, ForeheadRectangle to, double t) {
    if (!from.isValid || !to.isValid) {
      return to;
    }
    
    // 선형 보간 (텍스처 이미지는 to 값을 우선 사용)
    return ForeheadRectangle.withCurrentTime(
      center: Point<double>(
        from.center.x + (to.center.x - from.center.x) * t,
        from.center.y + (to.center.y - from.center.y) * t,
      ),
      width: from.width + (to.width - from.width) * t,
      height: from.height + (to.height - from.height) * t,
      rotationY: from.rotationY + (to.rotationY - from.rotationY) * t,
      rotationZ: from.rotationZ + (to.rotationZ - from.rotationZ) * t,
      scale: from.scale + (to.scale - from.scale) * t,
      isValid: true,
      textureImage: to.textureImage ?? from.textureImage, // 최신 이미지 사용
    );
  }
}