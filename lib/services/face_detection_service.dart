import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// ML Kit 얼굴 인식 서비스
class FaceDetectionService {
  static FaceDetector? _faceDetector;
  
  // FaceDetector 초기화 (정상 동작하는 example code와 동일한 설정)
  static Future<bool> initialize() async {
    try {
      // ML Kit 얼굴 인식 옵션 설정 (example code 방식)
      final options = FaceDetectorOptions(
        enableClassification: true,  // 감정 분류 활성화
        enableLandmarks: true,       // 랜드마크 활성화  
        enableTracking: true,        // 얼굴 추적 활성화
        performanceMode: FaceDetectorMode.fast, // FAST 모드 (example과 동일)
      );
      
      _faceDetector = FaceDetector(options: options);
      
      return true;
    } catch (e) {
      print('FaceDetector 초기화 실패: $e');
      return false;
    }
  }
  
  // FaceDetector가 초기화되었는지 확인
  static bool get isInitialized => _faceDetector != null;
  
  // CameraImage를 InputImage로 변환 (example code 방식으로 단순화)
  static InputImage? _inputImageFromCameraImage(CameraImage image, CameraController controller) {
    try {
      // Platform에 따라 format 결정 (example code와 동일)
      final format = Platform.isIOS ? InputImageFormat.bgra8888 : InputImageFormat.nv21;
      
      // sensorOrientation 기반 rotation 계산 (example code와 동일)
      final rotation = InputImageRotation.values.firstWhere(
        (element) => element.rawValue == controller.description.sensorOrientation,
        orElse: () => InputImageRotation.rotation0deg,
      );
      
      // 이미지 메타데이터 생성 (example code와 동일)
      final inputImageMetadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      );
      
      // 플레인 결합 (example code와 동일)
      final bytes = _concatenatePlanes(image.planes);
      
      // InputImage 생성
      return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
    } catch (e) {
      print('InputImage 변환 실패: $e');
      return null;
    }
  }

  // YUV420 플레인들을 결합하는 헬퍼 메서드
  static Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = <int>[];
    for (final plane in planes) {
      allBytes.addAll(plane.bytes);
    }
    return Uint8List.fromList(allBytes);
  }

  // 얼굴 감지 실행 (기본 버전 - bounding box만)
  static Future<List<Face>> detectFaces(CameraImage cameraImage, CameraController controller) async {
    if (!isInitialized) {
      print('FaceDetector가 초기화되지 않았습니다');
      return [];
    }
    
    try {
      // CameraImage를 InputImage로 변환
      final inputImage = _inputImageFromCameraImage(cameraImage, controller);
      if (inputImage == null) {
        return [];
      }
      
      // 얼굴 감지 실행
      final faces = await _faceDetector!.processImage(inputImage);
      
      // 디버깅: 얼굴 감지 결과 항상 출력
      print('=== 얼굴 감지 결과 ===');
      print('감지된 얼굴 수: ${faces.length}');
      if (faces.isEmpty) {
        print('⚠️ 얼굴이 감지되지 않았습니다');
        print('이미지 크기: ${inputImage.metadata?.size}');
        print('이미지 포맷: ${inputImage.metadata?.format}');
        print('회전값: ${inputImage.metadata?.rotation}');
      }
      
      return faces;
    } catch (e) {
      print('얼굴 감지 실패: $e');
      return [];
    }
  }
  
  // 리소스 정리
  static Future<void> dispose() async {
    try {
      await _faceDetector?.close();
      _faceDetector = null;
    } catch (e) {
      print('FaceDetector 정리 실패: $e');
    }
  }
  
  // 디버그 정보 출력
  static void printFaceInfo(List<Face> faces) {
    print('감지된 얼굴 수: ${faces.length}');
    for (int i = 0; i < faces.length; i++) {
      final face = faces[i];
      print('얼굴 $i:');
      print('  - Bounding Box: ${face.boundingBox}');
      print('  - Head Euler Angle Y: ${face.headEulerAngleY}');
      print('  - Head Euler Angle Z: ${face.headEulerAngleZ}');
      
      // 랜드마크가 있는 경우 출력
      if (face.landmarks.isNotEmpty) {
        print('  - 랜드마크 수: ${face.landmarks.length}');
        for (var entry in face.landmarks.entries) {
          final landmark = entry.value;
          if (landmark != null) {
            print('    ${entry.key}: ${landmark.position}');
          }
        }
      }
    }
  }
}