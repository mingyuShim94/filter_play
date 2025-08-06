import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';

/// 얼굴 감지 결과를 카메라 화면 위에 오버레이로 표시하는 위젯
class FaceDetectionOverlay extends StatelessWidget {
  final List<Face> faces;
  final Size previewSize;
  final Size screenSize;
  final CameraController cameraController;

  const FaceDetectionOverlay({
    super.key,
    required this.faces,
    required this.previewSize,
    required this.screenSize,
    required this.cameraController,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: FaceDetectionPainter(
        faces: faces,
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
  final Size previewSize;
  final Size screenSize;
  final CameraController cameraController;
  
  static bool _debugPrinted = false;  // 디버깅용 플래그

  FaceDetectionPainter({
    required this.faces,
    required this.previewSize,
    required this.screenSize,
    required this.cameraController,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 얼굴 bounding box 스타일 설정
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.green;

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
      canvas.drawRect(rect, paint);

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
    // 디버깅: 첫 번째 얼굴에 대해서만 좌표 정보 출력
    if (!_debugPrinted && faces.isNotEmpty) {
      print('=== 좌표 변환 디버깅 ===');
      print('Original rect: $rect');
      print('ImageSize: $imageSize');
      print('WidgetSize: $widgetSize');
      print('Camera: ${cameraController.description.lensDirection}');
      _debugPrinted = true;
    }
    
    // 화면과 이미지 크기 비율 계산 (example code와 동일)
    final double scaleX = widgetSize.width / imageSize.width;
    final double scaleY = widgetSize.height / imageSize.height;
    
    if (!_debugPrinted && faces.isNotEmpty) {
      print('ScaleX: $scaleX, ScaleY: $scaleY');
    }
    
    // 전면 카메라인 경우 horizontal flip 처리 (example code와 동일)
    double leftOffset = rect.left;
    if (cameraController.description.lensDirection == CameraLensDirection.front) {
      leftOffset = imageSize.width - rect.right;
    }
    
    // 좌표 변환 (example code와 동일)
    final double left = leftOffset * scaleX;
    final double top = rect.top * scaleY;
    final double right = (leftOffset + rect.width) * scaleX;
    final double bottom = (rect.top + rect.height) * scaleY;
    
    final result = Rect.fromLTRB(left, top, right, bottom);
    
    if (!_debugPrinted && faces.isNotEmpty) {
      print('LeftOffset: $leftOffset');
      print('Result rect: $result');
      _debugPrinted = true;
    }
    
    return result;
  }

  @override
  bool shouldRepaint(FaceDetectionPainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}