import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import '../services/lip_tracking_service.dart';
import '../services/forehead_rectangle_service.dart';

/// 얼굴 감지 결과를 카메라 화면 위에 오버레이로 표시하는 위젯
class FaceDetectionOverlay extends StatelessWidget {
  final List<Face> faces;
  final LipLandmarks? lipLandmarks; // T2C.2: 계산된 입술 랜드마크
  final ForeheadRectangle? foreheadRectangle; // 이마 사각형
  final Size previewSize;
  final Size screenSize;
  final CameraController cameraController;

  const FaceDetectionOverlay({
    super.key,
    required this.faces,
    this.lipLandmarks, // T2C.2: nullable 파라미터로 추가
    this.foreheadRectangle, // 이마 사각형 nullable 파라미터로 추가
    required this.previewSize,
    required this.screenSize,
    required this.cameraController,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: FaceDetectionPainter(
        faces: faces,
        lipLandmarks: lipLandmarks, // T2C.2: 계산된 입술 랜드마크 전달
        foreheadRectangle: foreheadRectangle, // 이마 사각형 전달
        previewSize: previewSize,
        screenSize: screenSize,
        cameraController: cameraController,
      ),
      child: Container(),
    );
  }
}

/// 얼굴 bounding box를 그리는 CustomPainter
class FaceDetectionPainter extends CustomPainter {
  final List<Face> faces;
  final LipLandmarks? lipLandmarks; // T2C.2: 계산된 입술 랜드마크
  final ForeheadRectangle? foreheadRectangle; // 이마 사각형
  final Size previewSize;
  final Size screenSize;
  final CameraController cameraController;

  static bool _debugPrinted = false; // 디버깅용 플래그

  FaceDetectionPainter({
    required this.faces,
    this.lipLandmarks, // T2C.2: nullable 파라미터로 추가
    this.foreheadRectangle, // 이마 사각형 nullable 파라미터로 추가
    required this.previewSize,
    required this.screenSize,
    required this.cameraController,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 디버깅 플래그 초기화 (매번 새로운 프레임마다 로그 출력을 위해)
    _debugPrinted = false;

    // 얼굴 bounding box 스타일 설정
    final facePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.green;

    // 랜드마크는 _drawLandmarks에서 별도로 처리

    // 얼굴 개수 텍스트 스타일
    final textStyle = TextStyle(
      color: Colors.green,
      fontSize: 16,
      fontWeight: FontWeight.bold,
      backgroundColor: Colors.black.withValues(alpha: 0.7),
    );

    for (final face in faces) {
      // ML Kit 좌표를 화면 좌표로 변환
      final rect = _scaleRect(
        rect: face.boundingBox,
        imageSize: previewSize,
        widgetSize: size,
      );

      // 얼굴 bounding box 그리기
      canvas.drawRect(rect, facePaint);

      // T2C.1 & T2C.2: 얼굴 랜드마크 그리기 (입술은 빨간색으로 구분)
      _drawLandmarks(canvas, face, size);
      
      // T2C.2: 계산된 입술 중심점들 그리기 (노란색, 보라색으로 구분)
      _drawLipCenterPoints(canvas, size);
      
      // 이마 사각형 그리기
      _drawForeheadRectangle(canvas, size);

      // 얼굴 ID나 신뢰도가 있다면 텍스트로 표시
      final textSpan = TextSpan(
        text: 'Face',
        style: textStyle,
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // bounding box 상단에 텍스트 표시
      textPainter.paint(
        canvas,
        Offset(rect.left, rect.top - textPainter.height - 4),
      );
    }

    // 전체 얼굴 개수 표시 (좌상단)
    if (faces.isNotEmpty) {
      final countText = TextSpan(
        text: '감지된 얼굴: ${faces.length}개',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          backgroundColor: Colors.green.withValues(alpha: 0.8),
        ),
      );

      final countPainter = TextPainter(
        text: countText,
        textDirection: TextDirection.ltr,
      );

      countPainter.layout();

      // 왼쪽 상단에 개수 표시
      final backgroundRect = Rect.fromLTWH(
        8,
        8,
        countPainter.width + 16,
        countPainter.height + 8,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(backgroundRect, const Radius.circular(4)),
        Paint()..color = Colors.green.withValues(alpha: 0.8),
      );

      countPainter.paint(canvas, const Offset(16, 12));
    }
  }

  /// ML Kit 좌표를 화면 좌표로 변환 (example code 방식)
  Rect _scaleRect({
    required Rect rect,
    required Size imageSize,
    required Size widgetSize,
  }) {
    // 디버깅: 첫 번째 얼굴에 대해서만 좌표 정보 출력 (개발용)
    if (kDebugMode && !_debugPrinted && faces.isNotEmpty) {
      print('=== Bounding Box 변환 디버깅 ===');
      print('Camera: ${cameraController.description.lensDirection}');
      print('ImageSize: $imageSize, WidgetSize: $widgetSize');
      _debugPrinted = true;
    }

    // 화면과 이미지 크기 비율 계산 (example code와 동일)
    final double scaleX = widgetSize.width / imageSize.width;
    final double scaleY = widgetSize.height / imageSize.height;

    // 좌표 오프셋 (전면카메라 변환은 랜드마크에서만 처리)
    double leftOffset = rect.left;

    // 좌표 변환 (example code와 동일)
    final double left = leftOffset * scaleX;
    final double top = rect.top * scaleY;
    final double right = (leftOffset + rect.width) * scaleX;
    final double bottom = (rect.top + rect.height) * scaleY;

    final result = Rect.fromLTRB(left, top, right, bottom);

    return result;
  }

  /// 개별 얼굴의 모든 랜드마크를 그리는 메서드 (example code 참조)
  void _drawLandmarks(Canvas canvas, Face face, Size widgetSize) {
    // 기본 랜드마크 포인트 스타일 (파란색)
    final landmarkPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.blue;

    // T2C.2: 입술 랜드마크 전용 스타일 (빨간색)
    final lipLandmarkPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.red;

    // 화면과 이미지 크기 비율 계산
    final double scaleX = widgetSize.width / previewSize.width;
    final double scaleY = widgetSize.height / previewSize.height;

    // 개별 랜드마크를 그리는 헬퍼 함수 (example code 방식)
    void drawLandmark(FaceLandmarkType type,
        {bool isLipLandmark = false, double radius = 4.0}) {
      if (face.landmarks[type] != null) {
        final point = face.landmarks[type]!.position;
        final originalX = point.x.toDouble();
        double pointX = originalX;

        // 좌표 스케일링 적용하여 원 그리기
        canvas.drawCircle(
          Offset(pointX * scaleX, point.y * scaleY),
          radius,
          isLipLandmark ? lipLandmarkPaint : landmarkPaint,
        );
      }
    }

    // T2C.1: 일반 얼굴 랜드마크 그리기 (파란색)
    drawLandmark(FaceLandmarkType.leftEye);
    drawLandmark(FaceLandmarkType.rightEye);
    drawLandmark(FaceLandmarkType.noseBase);
    drawLandmark(FaceLandmarkType.leftEar);
    drawLandmark(FaceLandmarkType.rightEar);
    drawLandmark(FaceLandmarkType.leftCheek);
    drawLandmark(FaceLandmarkType.rightCheek);

    // T2C.2: 입술 특정 랜드마크 그리기 (빨간색, 큰 원)
    drawLandmark(FaceLandmarkType.leftMouth, isLipLandmark: true, radius: 6.0);
    drawLandmark(FaceLandmarkType.rightMouth, isLipLandmark: true, radius: 6.0);
    drawLandmark(FaceLandmarkType.bottomMouth,
        isLipLandmark: true, radius: 6.0);
  }

  /// T2C.2: 계산된 입술 중심점들을 그리는 메서드
  void _drawLipCenterPoints(Canvas canvas, Size widgetSize) {
    // 입술 랜드마크가 없으면 리턴
    if (lipLandmarks == null || !lipLandmarks!.isComplete) return;

    // 화면과 이미지 크기 비율 계산
    final double scaleX = widgetSize.width / previewSize.width;
    final double scaleY = widgetSize.height / previewSize.height;

    // 윗입술 중심점 스타일 (노란색)
    final upperLipPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.yellow;

    // 입술 전체 중심점 스타일 (보라색)
    final centerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.purple;

    // 계산된 중심점 그리기 헬퍼 함수
    void drawCenterPoint(Point<double>? point, Paint paint, double radius) {
      if (point != null) {
        // 좌표 스케일링 적용하여 원 그리기
        canvas.drawCircle(
          Offset(point.x * scaleX, point.y * scaleY),
          radius,
          paint,
        );
      }
    }

    // 윗입술 중심점 그리기 (노란색, 중간 크기)
    drawCenterPoint(lipLandmarks!.upperLip, upperLipPaint, 5.0);

    // 입술 전체 중심점 그리기 (보라색, 큰 크기)
    drawCenterPoint(lipLandmarks!.center, centerPaint, 7.0);
  }

  /// 이마 사각형 그리기
  void _drawForeheadRectangle(Canvas canvas, Size widgetSize) {
    // 이마 사각형이 없거나 유효하지 않으면 리턴
    if (foreheadRectangle == null || !foreheadRectangle!.isValid) return;

    // 화면과 이미지 크기 비율 계산
    final double scaleX = widgetSize.width / previewSize.width;
    final double scaleY = widgetSize.height / previewSize.height;

    final rect = foreheadRectangle!;
    
    // 화면 좌표로 변환된 중심점
    final centerX = rect.center.x * scaleX;
    final centerY = rect.center.y * scaleY;
    
    // 스케일이 적용된 사각형 크기
    final scaledWidth = rect.width * rect.scale * scaleX;
    final scaledHeight = rect.height * rect.scale * scaleY;

    // 사각형 Paint 설정 - 3D 효과를 위한 그라데이션 색상
    final rectPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // 고정된 색상과 투명도 (안정적인 표시)
    rectPaint.color = Colors.white.withValues(alpha: 0.8);

    // Canvas 저장
    canvas.save();

    // 중심점으로 이동
    canvas.translate(centerX, centerY);

    // Z축 회전 (기울기) 적용 - 방향 반전으로 얼굴 기울기와 일치
    canvas.rotate(-rect.rotationZ * pi / 180);

    // Y축 회전을 원근감으로 표현 (스케일 변형)
    final perspectiveScale = cos(rect.rotationY * pi / 180).abs();
    final skewX = sin(rect.rotationY * pi / 180) * 0.3;
    
    // 변형 행렬 적용 (원근감)
    final transform = Matrix4.identity()
      ..setEntry(0, 0, perspectiveScale) // X축 스케일
      ..setEntry(0, 1, skewX); // X축 기울기 (원근감)
    
    canvas.transform(transform.storage);

    // 사각형 그리기 (중심 기준)
    final drawRect = Rect.fromCenter(
      center: Offset.zero,
      width: scaledWidth,
      height: scaledHeight,
    );

    // 이미지가 있으면 이미지로 채우기, 없으면 기본 사각형 그리기
    if (rect.textureImage != null) {
      // 이미지를 사각형 영역에 맞게 그리기
      final srcRect = Rect.fromLTWH(
        0, 0, 
        rect.textureImage!.width.toDouble(), 
        rect.textureImage!.height.toDouble()
      );
      
      // 자연스러운 이미지 표시 (외곽선 없음)
      final imagePaint = Paint()
        ..color = Colors.white.withValues(alpha: 1.0) // 완전 불투명
        ..filterQuality = FilterQuality.high; // 고품질 렌더링
      
      canvas.drawImageRect(rect.textureImage!, srcRect, drawRect, imagePaint);
    } else {
      // 기본 사각형 렌더링 (이미지가 없는 경우)
      
      // 외곽선 그리기
      canvas.drawRect(drawRect, rectPaint);
      
      // 이너 글로우 효과 (여러 레이어)
      for (int i = 3; i > 0; i--) {
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i * 2.0
          ..color = rectPaint.color.withValues(alpha: 0.1 / i);
        canvas.drawRect(drawRect, glowPaint);
      }

      // 내부 채우기 (고정된 투명도)
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = rectPaint.color.withValues(alpha: 0.2);
      canvas.drawRect(drawRect, fillPaint);
    }

    // 중심점 표시 제거 (더 깔끔한 효과)

    // Canvas 복원
    canvas.restore();

    // 디버깅: 이마 사각형 정보 출력 (120프레임마다)
    if (kDebugMode && !_debugPrinted) {
      print('ForeheadRectangle Draw: center(${centerX.toStringAsFixed(1)}, ${centerY.toStringAsFixed(1)}), '
            'size(${scaledWidth.toStringAsFixed(1)} x ${scaledHeight.toStringAsFixed(1)}), '
            'rotY: ${rect.rotationY.toStringAsFixed(1)}°, rotZ: ${rect.rotationZ.toStringAsFixed(1)}°');
    }
  }

  @override
  bool shouldRepaint(FaceDetectionPainter oldDelegate) {
    return oldDelegate.faces != faces || 
           oldDelegate.foreheadRectangle != foreheadRectangle;
  }
}
