import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// T2C.4: 입 상태 enum 정의
enum MouthState {
  closed, // 입 닫힘 상태
  open, // 입 열림 상태

  unknown // 감지 실패 또는 불확실한 상태
}

/// T2C.4: 동적 threshold 관리 및 상태 판정 클래스
class MouthStateDetector {
  // 기본 threshold 값들 (정규화된 값 기준) - 입 닫힘 인식 개선 v2 (더 관대하게)
  static const double _defaultOpenThreshold =
      0.030; // 입 열림 판정 임계값 (0.020 → 0.025, 더 확실한 열림만)
  static const double _defaultCloseThreshold =
      0.013; // 입 닫힘 판정 임계값 (0.012 → 0.015, 살짝 닫힘도 인식)

  // 적응형 threshold (사용자별 자동 조정)
  double _currentOpenThreshold = _defaultOpenThreshold;
  double _currentCloseThreshold = _defaultCloseThreshold;

  // 캘리브레이션 관련
  final List<double> _calibrationSamples = [];
  bool _isCalibrated = false;
  static const int _calibrationSampleCount = 60; // 2초간 샘플링 (30fps 기준)

  // 디버깅 관련 (입 닫힘 인식 개선)
  int _frameDebugCounter = 0;

  /// 입술 상태 판정 (히스테리시스 적용) - 입 닫힘 인식 개선
  MouthState detectState(LipLandmarks lips, MouthState previousState) {
    if (!lips.isComplete) return MouthState.unknown;

    final normalizedHeight = lips.normalizedLipHeight;

    // 디버깅: 30프레임마다 현재 값과 threshold 비교 출력 (입 닫힘 인식 개선)
    if (kDebugMode && _frameDebugCounter++ % 30 == 0 && _isCalibrated) {
      print('T2C.4 Debug: Height=${normalizedHeight.toStringAsFixed(4)}, '
          'Close=${_currentCloseThreshold.toStringAsFixed(4)}, '
          'Open=${_currentOpenThreshold.toStringAsFixed(4)}, '
          'State=${previousState.name}');
    }

    // 캘리브레이션이 완료되지 않았다면 샘플 수집
    if (!_isCalibrated) {
      _collectCalibrationSample(normalizedHeight);
      return MouthState.unknown; // 캘리브레이션 중에는 unknown 반환
    }

    // 히스테리시스를 적용한 상태 판정
    switch (previousState) {
      case MouthState.closed:
      case MouthState.unknown:
        // 닫힘 상태에서는 열림 threshold를 넘어야 열림으로 판정
        return normalizedHeight > _currentOpenThreshold
            ? MouthState.open
            : MouthState.closed;

      case MouthState.open:
        // 열림 상태에서는 닫힘 threshold 아래로 내려가야 닫힘으로 판정
        return normalizedHeight < _currentCloseThreshold
            ? MouthState.closed
            : MouthState.open;
    }
  }

  /// 캘리브레이션 샘플 수집 및 처리
  void _collectCalibrationSample(double normalizedHeight) {
    _calibrationSamples.add(normalizedHeight);

    if (_calibrationSamples.length >= _calibrationSampleCount) {
      _performCalibration();
      _isCalibrated = true;
    }
  }

  /// 수집된 샘플을 기반으로 개인화된 threshold 계산
  void _performCalibration() {
    if (_calibrationSamples.isEmpty) return;

    _calibrationSamples.sort();

    // 입 닫힘 인식 개선 v2: 30th 백분위수를 닫힘 threshold로, 80th 백분위수를 열림 threshold로 설정 (더 관대하게)
    final int closeIndex =
        (_calibrationSamples.length * 0.30).round(); // 10th → 30th (살짝 닫힘도 인식)
    final int openIndex =
        (_calibrationSamples.length * 0.80).round(); // 90th → 80th (적당한 열림)

    _currentCloseThreshold = _calibrationSamples[closeIndex];
    _currentOpenThreshold = _calibrationSamples[openIndex];

    // 최소 간격 보장 (입 닫힘 인식 개선 v2: 0.008 → 0.010, 적절한 히스테리시스)
    final gap = _currentOpenThreshold - _currentCloseThreshold;
    if (gap < 0.010) {
      _currentCloseThreshold = _defaultCloseThreshold;
      _currentOpenThreshold = _defaultOpenThreshold;
    }

    if (kDebugMode) {
      print('T2C.4: 캘리브레이션 완료 (입 닫힘 인식 개선 v2 - 더 관대하게)');
      print(
          '- Close Threshold: ${_currentCloseThreshold.toStringAsFixed(4)} (30th 백분위수)');
      print(
          '- Open Threshold: ${_currentOpenThreshold.toStringAsFixed(4)} (80th 백분위수)');
      print('- Gap: ${gap.toStringAsFixed(4)} (히스테리시스 간격)');
      print('- 샘플 수: ${_calibrationSamples.length}');
      print('- 전략: 살짝 닫힌 상태도 CLOSED로 인식');
    }
  }

  /// 현재 threshold 값들 반환
  Map<String, double> get thresholds => {
        'open': _currentOpenThreshold,
        'close': _currentCloseThreshold,
      };

  /// 캘리브레이션 상태 반환
  bool get isCalibrated => _isCalibrated;

  /// 캘리브레이션 진행률 (0.0-1.0)
  double get calibrationProgress => _isCalibrated
      ? 1.0
      : _calibrationSamples.length / _calibrationSampleCount;
}

/// 입술 랜드마크 정보를 담는 데이터 클래스
class LipLandmarks {
  final Point<double>? upperLip; // 윗입술 중심점 (leftMouth와 rightMouth의 중점)
  final Point<double>? lowerLip; // 아랫입술 중심점 (bottomMouth)
  final Point<double>? leftCorner; // 입술 좌측 모서리
  final Point<double>? rightCorner; // 입술 우측 모서리
  final Point<double>? center; // 입술 전체 중심점
  final Size? faceSize; // T2C.3: 얼굴 크기 (정규화를 위한)

  const LipLandmarks({
    this.upperLip,
    this.lowerLip,
    this.leftCorner,
    this.rightCorner,
    this.center,
    this.faceSize, // T2C.3: 얼굴 크기 정보 추가
  });

  /// 모든 주요 입술 랜드마크가 감지되었는지 확인
  bool get isComplete => upperLip != null && lowerLip != null;

  /// 입술 높이 (윗입술과 아랫입술 간의 거리)
  double get lipHeight {
    if (!isComplete) return 0.0;
    return _calculateDistance(upperLip!, lowerLip!);
  }

  /// 입술 너비 (좌우 모서리 간의 거리)
  double get lipWidth {
    if (leftCorner == null || rightCorner == null) return 0.0;
    return _calculateDistance(leftCorner!, rightCorner!);
  }

  /// T2C.3: 얼굴 크기 대비 정규화된 입술 높이 (0.0-1.0)
  double get normalizedLipHeight {
    if (!isComplete || faceSize == null) return 0.0;
    // 얼굴 높이 대비 입술 높이 비율 계산
    return lipHeight / faceSize!.height;
  }

  /// T2C.3: 얼굴 크기 대비 정규화된 입술 너비 (0.0-1.0)
  double get normalizedLipWidth {
    if (leftCorner == null || rightCorner == null || faceSize == null)
      return 0.0;
    // 얼굴 너비 대비 입술 너비 비율 계산
    return lipWidth / faceSize!.width;
  }

  /// T2C.3: 입술 개방 비율 (높이/너비, 입 벌림 정도 측정용)
  double get lipOpenRatio {
    if (!isComplete || lipWidth == 0.0) return 0.0;
    return lipHeight / lipWidth;
  }

  /// T2C.4: MouthStateDetector를 이용한 상태 판정
  MouthState getMouthState(
      MouthStateDetector detector, MouthState previousState) {
    return detector.detectState(this, previousState);
  }

  /// 두 점 사이의 유클리드 거리 계산
  double _calculateDistance(Point<double> p1, Point<double> p2) {
    final dx = p1.x - p2.x;
    final dy = p1.y - p2.y;
    return sqrt(dx * dx + dy * dy);
  }
}

/// T2C.2 & T2C.3: 입술 특정 랜드마크 추출 및 거리 계산 서비스
class LipTrackingService {
  /// T2C.3: Face 객체에서 얼굴 크기 계산
  static Size _calculateFaceSize(Face face) {
    final boundingBox = face.boundingBox;
    return Size(boundingBox.width, boundingBox.height);
  }

  /// Face 객체에서 입술 랜드마크를 추출 (T2C.3: 얼굴 크기 정보 포함)
  /// 원본 ML Kit 좌표를 그대로 사용 (화면 표시 변환은 overlay에서 처리)
  static LipLandmarks extractLipLandmarks(Face face) {
    try {
      // ML Kit에서 제공하는 입술 관련 랜드마크 추출 (원본 좌표 사용)
      final leftMouth = face.landmarks[FaceLandmarkType.leftMouth]?.position;
      final rightMouth = face.landmarks[FaceLandmarkType.rightMouth]?.position;
      final bottomMouth =
          face.landmarks[FaceLandmarkType.bottomMouth]?.position;

      // 윗입술 중심점 계산 (좌우 입꼬리의 중점)
      Point<double>? upperLip;
      if (leftMouth != null && rightMouth != null) {
        upperLip = Point(
          (leftMouth.x + rightMouth.x) / 2,
          (leftMouth.y + rightMouth.y) / 2,
        );
      }

      // 아랫입술은 bottomMouth 그대로 사용
      Point<double>? lowerLip;
      if (bottomMouth != null) {
        lowerLip = Point(bottomMouth.x.toDouble(), bottomMouth.y.toDouble());
      }

      // 전체 입술 중심점 계산
      Point<double>? center;
      if (upperLip != null && lowerLip != null) {
        center = Point(
          (upperLip.x + lowerLip.x) / 2,
          (upperLip.y + lowerLip.y) / 2,
        );
      }

      // 좌우 모서리
      Point<double>? leftCorner;
      if (leftMouth != null) {
        leftCorner = Point(leftMouth.x.toDouble(), leftMouth.y.toDouble());
      }

      Point<double>? rightCorner;
      if (rightMouth != null) {
        rightCorner = Point(rightMouth.x.toDouble(), rightMouth.y.toDouble());
      }

      // T2C.3: 얼굴 크기 계산
      final faceSize = _calculateFaceSize(face);

      return LipLandmarks(
        upperLip: upperLip,
        lowerLip: lowerLip,
        leftCorner: leftCorner,
        rightCorner: rightCorner,
        center: center,
        faceSize: faceSize, // T2C.3: 정규화를 위한 얼굴 크기 정보 포함
      );
    } catch (e) {
      if (kDebugMode) print('입술 랜드마크 추출 실패: $e');
      return const LipLandmarks();
    }
  }

  /// T2C.3: 확장된 입술 거리 정보 출력 (개발용)
  static void printLipLandmarks(LipLandmarks lips) {
    if (!kDebugMode) return;

    print('=== T2C.3: 입술 거리 계산 정보 ===');
    print('윗입술: ${lips.upperLip}');
    print('아랫입술: ${lips.lowerLip}');
    print('좌측 모서리: ${lips.leftCorner}');
    print('우측 모서리: ${lips.rightCorner}');
    print('입술 중심: ${lips.center}');
    print('얼굴 크기: ${lips.faceSize}');
    print('--- 거리 측정 ---');
    print('입술 높이: ${lips.lipHeight.toStringAsFixed(2)}px');
    print('입술 너비: ${lips.lipWidth.toStringAsFixed(2)}px');
    print('--- 정규화된 거리 ---');
    print('정규화 높이: ${lips.normalizedLipHeight.toStringAsFixed(4)} (0-1)');
    print('정규화 너비: ${lips.normalizedLipWidth.toStringAsFixed(4)} (0-1)');
    print('개방 비율: ${lips.lipOpenRatio.toStringAsFixed(4)} (높이/너비)');
    print('완료 상태: ${lips.isComplete}');
  }
}
