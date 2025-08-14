# Google ML Kit Face Detection for Flutter

## 개요

Flutter 앱에서 Google ML Kit을 사용한 얼굴 감지 기능 구현을 위한 공식 플러그인입니다.

**패키지 정보:**
- **최신 버전:** 0.13.1
- **플랫폼 지원:** Android, iOS
- **Flutter 호환:** Dart 3 compatible
- **라이센스:** MIT

## 주요 특징

- 이미지에서 얼굴 감지
- 주요 얼굴 특징점(랜드마크) 식별  
- 감지된 얼굴의 윤곽선 추출
- 머리 각도 및 표정 분석
- 실시간 얼굴 추적

## 시스템 요구사항

### iOS
- **최소 iOS 버전:** 15.5
- **Xcode:** 15.3.0 이상
- **Swift:** 5
- **아키텍처:** 64-bit만 지원 (x86_64, arm64)
- **지원하지 않음:** 32-bit (i386, armv7)

### Android  
- **minSdkVersion:** 21
- **targetSdkVersion:** 35
- **compileSdkVersion:** 35

## 설치

### 1. pubspec.yaml에 의존성 추가

```yaml
dependencies:
  google_mlkit_face_detection: ^0.13.1
  google_mlkit_commons: ^0.6.0  # 공통 유틸리티 (InputImage 생성용)
```

### 2. iOS 설정 (Podfile)

```ruby
platform :ios, '15.5'  # 또는 더 최신 버전

# 변수 설정
$iOSVersion = '15.5'  # 또는 더 최신 버전

post_install do |installer|
  # 프로젝트 빌드 설정
  installer.pods_project.build_configurations.each do |config|
    config.build_settings["EXCLUDED_ARCHS[sdk=*]"] = "armv7"
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = $iOSVersion
  end

  # 타겟별 빌드 설정
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)

    target.build_configurations.each do |config|
      if Gem::Version.new($iOSVersion) > Gem::Version.new(config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'])
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = $iOSVersion
      end
    end
  end
end
```

### 3. Android 설정

별도 설정이 필요하지 않으며, minSdkVersion 21 이상인지만 확인하면 됩니다.

## google_mlkit_commons 패키지

Google ML Kit Flutter 플러그인들에서 공통으로 사용되는 메서드와 클래스를 제공합니다.

### 주요 기능
- **InputImage 생성:** 다양한 소스로부터 InputImage 객체 생성
- **이미지 회전 처리:** Android/iOS 플랫폼별 이미지 회전 계산
- **메타데이터 관리:** 이미지 포맷, 크기, 회전 정보 등

### 플랫폼 채널 아키텍처

ML Kit 처리는 Flutter/Dart에서 수행되지 않습니다. 모든 호출은 플랫폼 채널을 통해 네이티브 플랫폼으로 전달되어 Google의 네이티브 API에서 실행됩니다.

- **Android:** MethodChannel을 통한 Java 네이티브 API 호출
- **iOS:** FlutterMethodChannel을 통한 Objective-C 네이티브 API 호출

## 기본 사용법

### 1. InputImage 생성

InputImage는 ML Kit에서 이미지 처리를 위해 사용되는 핵심 클래스입니다. 다양한 방법으로 생성할 수 있습니다.

#### 1.1 파일 경로로부터 생성

```dart
final inputImage = InputImage.fromFilePath(filePath);
```

#### 1.2 File 객체로부터 생성

```dart
final inputImage = InputImage.fromFile(file);
```

#### 1.3 바이트 데이터로부터 생성

```dart
final inputImage = InputImage.fromBytes(
  bytes: bytes, 
  metadata: metadata  // InputImageMetadata 필요
);
```

#### 1.4 비트맵 데이터로부터 생성

```dart
// UI 이미지를 비트맵으로 변환하여 InputImage 생성
final ui.Image image = await recorder.endRecording().toImage(width, height);
final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

final InputImage inputImage = InputImage.fromBitmap(
  bitmap: byteData!.buffer.asUint8List(),
  width: width,
  height: height,
  rotation: 0,  // 선택사항, 기본값 0, Android에서만 사용
);
```

#### 1.5 Camera 플러그인으로부터 생성 (실시간 처리)

**중요:** Camera 플러그인 사용 시 반드시 다음 포맷을 사용해야 합니다:
- **Android:** ImageFormatGroup.nv21
- **iOS:** ImageFormatGroup.bgra8888

```dart
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:flutter/services.dart';

// 카메라 설정 - 필수 포맷 지정
final controller = CameraController(
  camera,
  ResolutionPreset.medium,
  enableAudio: false,
  imageFormatGroup: Platform.isAndroid
    ? ImageFormatGroup.nv21      // Android 전용 포맷
    : ImageFormatGroup.bgra8888, // iOS 전용 포맷
);

// 이미지 회전 계산을 위한 방향 매핑
final _orientations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

// CameraImage를 InputImage로 변환하는 핵심 함수
InputImage? inputImageFromCameraImage(CameraImage image) {
  // 1. 이미지 회전 정보 계산
  // Android: InputImage를 Dart에서 Java로 변환할 때 사용
  // iOS: Dart에서 Obj-C로 변환할 때는 사용되지 않음
  // 두 플랫폼 모두에서 캔버스의 x, y 좌표 보정에 사용 가능
  final camera = cameras[cameraIndex];
  final sensorOrientation = camera.sensorOrientation;
  InputImageRotation? rotation;
  
  if (Platform.isIOS) {
    rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
  } else if (Platform.isAndroid) {
    var rotationCompensation = _orientations[controller.value.deviceOrientation];
    if (rotationCompensation == null) return null;
    
    if (camera.lensDirection == CameraLensDirection.front) {
      // 전면 카메라
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      // 후면 카메라
      rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
    }
    rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
  }
  
  if (rotation == null) return null;

  // 2. 이미지 포맷 검증
  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  
  // 지원되는 포맷만 허용:
  // - Android: nv21만
  // - iOS: bgra8888만
  if (format == null ||
      (Platform.isAndroid && format != InputImageFormat.nv21) ||
      (Platform.isIOS && format != InputImageFormat.bgra8888)) {
    return null;
  }

  // 3. 플레인 수 검증 (nv21과 bgra8888은 모두 단일 플레인)
  if (image.planes.length != 1) return null;
  final plane = image.planes.first;

  // 4. InputImage 생성
  return InputImage.fromBytes(
    bytes: plane.bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,  // Android에서만 사용
      format: format,      // iOS에서만 사용
      bytesPerRow: plane.bytesPerRow,  // iOS에서만 사용
    ),
  );
}

// 사용 예시
CameraImage image; // 카메라 스트림으로부터 받은 이미지
final inputImage = inputImageFromCameraImage(image);
if (inputImage != null) {
  // ML Kit으로 처리
  final faces = await faceDetector.processImage(inputImage);
}
```

### 2. FaceDetector 초기화

```dart
final options = FaceDetectorOptions();
final faceDetector = FaceDetector(options: options);
```

### 3. 얼굴 감지 수행

```dart
final List<Face> faces = await faceDetector.processImage(inputImage);
```

### 4. 감지 결과 처리

```dart
for (Face face in faces) {
  final Rect boundingBox = face.boundingBox;

  // 머리 각도 정보
  final double? rotX = face.headEulerAngleX; // 상하 기울기 각도
  final double? rotY = face.headEulerAngleY; // 좌우 회전 각도  
  final double? rotZ = face.headEulerAngleZ; // 좌우 기울기 각도

  // 얼굴 랜드마크 (옵션에서 활성화된 경우)
  final FaceLandmark? leftEar = face.landmarks[FaceLandmarkType.leftEar];
  if (leftEar != null) {
    final Point<int> leftEarPos = leftEar.position;
  }

  // 표정 분석 (옵션에서 활성화된 경우)
  if (face.smilingProbability != null) {
    final double? smileProb = face.smilingProbability;
  }

  // 얼굴 추적 ID (옵션에서 활성화된 경우)
  if (face.trackingId != null) {
    final int? id = face.trackingId;
  }
}
```

### 5. 리소스 해제

```dart
faceDetector.close();
```

## FaceDetectorOptions 설정

### 기본 설정

```dart
final options = FaceDetectorOptions(
  enableContours: false,       // 얼굴 윤곽선 감지
  enableLandmarks: false,      // 랜드마크 감지
  enableClassification: false, // 표정 분류 (미소 확률 등)
  enableTracking: false,       // 얼굴 추적
  minFaceSize: 0.15,          // 최소 얼굴 크기 (0.0 ~ 1.0)
  performanceMode: FaceDetectorMode.fast, // 성능 모드
);
```

### 성능 모드

- **FaceDetectorMode.fast:** 빠른 감지 (권장)
- **FaceDetectorMode.accurate:** 정확한 감지

### 성능 최적화 팁

```dart
// 성능 우선 설정 (FilterPlay 앱에 권장)
final options = FaceDetectorOptions(
  performanceMode: FaceDetectorMode.fast,
  enableLandmarks: true,        // 입 움직임 감지용
  enableClassification: false,  // 성능 향상
  enableTracking: false,        // 성능 향상
  enableContours: false,        // 성능 향상
  minFaceSize: 0.15,           // 적절한 최소 크기
);
```

## 사용 가능한 랜드마크

### FaceLandmarkType 종류

```dart
// 귀
FaceLandmarkType.leftEar
FaceLandmarkType.rightEar

// 눈
FaceLandmarkType.leftEye
FaceLandmarkType.rightEye

// 볼
FaceLandmarkType.leftCheek
FaceLandmarkType.rightCheek

// 코
FaceLandmarkType.noseBase

// 입
FaceLandmarkType.bottomMouth
FaceLandmarkType.leftMouth
FaceLandmarkType.rightMouth
```

### 입 움직임 감지 예시 (FilterPlay용)

```dart
bool isMouthOpen(Face face, double threshold) {
  final bottomMouth = face.landmarks[FaceLandmarkType.bottomMouth];
  final leftMouth = face.landmarks[FaceLandmarkType.leftMouth];
  final rightMouth = face.landmarks[FaceLandmarkType.rightMouth];

  if (bottomMouth != null && leftMouth != null && rightMouth != null) {
    // 입 높이 계산
    final mouthWidth = (rightMouth.position.x - leftMouth.position.x).abs();
    final mouthHeight = (bottomMouth.position.y - ((leftMouth.position.y + rightMouth.position.y) / 2)).abs();
    
    // 비율 계산으로 입 벌림 감지
    final mouthAspectRatio = mouthHeight / mouthWidth;
    return mouthAspectRatio > threshold;
  }
  
  return false;
}
```

## Camera 플러그인과 통합

### 카메라 설정

```dart
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

final controller = CameraController(
  camera,
  ResolutionPreset.medium,  // 성능을 위해 medium 사용
  enableAudio: false,
  imageFormatGroup: Platform.isAndroid
    ? ImageFormatGroup.nv21      // Android 최적 포맷
    : ImageFormatGroup.bgra8888, // iOS 최적 포맷
);
```

### CameraImage를 InputImage로 변환

```dart
InputImage? inputImageFromCameraImage(CameraImage cameraImage) {
  // 회전 정보 계산
  final camera = cameras[selectedCameraIndex];
  final sensorOrientation = camera.sensorOrientation;
  InputImageRotation? rotation;
  
  if (Platform.isIOS) {
    rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
  } else if (Platform.isAndroid) {
    var rotationCompensation = _orientations[controller.value.deviceOrientation];
    if (rotationCompensation == null) return null;
    
    if (camera.lensDirection == CameraLensDirection.front) {
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
    }
    rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
  }
  
  if (rotation == null) return null;

  // 포맷 검증
  final format = InputImageFormatValue.fromRawValue(cameraImage.format.raw);
  if (format == null ||
      (Platform.isAndroid && format != InputImageFormat.nv21) ||
      (Platform.isIOS && format != InputImageFormat.bgra8888)) {
    return null;
  }

  // InputImage 생성
  return InputImage.fromBytes(
    bytes: cameraImage.planes.first.bytes,
    metadata: InputImageMetadata(
      size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: cameraImage.planes.first.bytesPerRow,
    ),
  );
}

// 디바이스 방향 매핑
final _orientations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};
```

## FilterPlay 프로젝트 통합 예시

### FaceDetectionService에서 사용

```dart
class FaceDetectionService {
  static FaceDetector? _faceDetector;
  
  static Future<void> initialize() async {
    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: true,  // 입 움직임 감지용
      enableClassification: false,
      enableTracking: false,
      enableContours: false,
      minFaceSize: 0.15,
    );
    
    _faceDetector = FaceDetector(options: options);
  }
  
  static Future<List<Face>> detectFaces(InputImage inputImage) async {
    if (_faceDetector == null) await initialize();
    return await _faceDetector!.processImage(inputImage);
  }
  
  static void dispose() {
    _faceDetector?.close();
    _faceDetector = null;
  }
}
```

## 에러 처리

```dart
try {
  final List<Face> faces = await faceDetector.processImage(inputImage);
  // 얼굴 감지 성공 처리
  if (faces.isNotEmpty) {
    print('${faces.length}개의 얼굴을 감지했습니다.');
  }
} on PlatformException catch (e) {
  print('플랫폼 에러: ${e.message}');
} catch (e) {
  print('얼굴 감지 에러: $e');
}
```

## 성능 최적화 방법

### 1. 적절한 옵션 선택
- 필요한 기능만 활성화
- 빠른 모드 사용
- 적절한 최소 얼굴 크기 설정

### 2. 이미지 처리 최적화
- 해상도를 적절히 조정 (ResolutionPreset.medium)
- 모든 프레임을 처리하지 않고 간격을 둠

### 3. 메모리 관리
- 사용 후 반드시 `close()` 호출
- 불필요한 InputImage 생성 최소화

## 문제 해결

### 일반적인 문제
1. **iOS 빌드 실패:** Podfile 설정 확인
2. **32-bit 아키텍처 에러:** armv7 제외 설정 확인  
3. **성능 문제:** 옵션 최적화 및 해상도 조정
4. **InputImage 생성 실패:** 이미지 포맷과 회전 정보 검증
5. **카메라 이미지 처리 오류:** ImageFormatGroup 설정 확인

### InputImage 관련 문제 해결

#### 지원되지 않는 포맷 에러
```dart
// ❌ 잘못된 설정
imageFormatGroup: ImageFormatGroup.jpeg  // 지원하지 않음

// ✅ 올바른 설정
imageFormatGroup: Platform.isAndroid
  ? ImageFormatGroup.nv21      // Android
  : ImageFormatGroup.bgra8888  // iOS
```

#### 플레인 수 불일치 에러
```dart
// nv21과 bgra8888은 반드시 단일 플레인이어야 함
if (image.planes.length != 1) {
  print('지원하지 않는 플레인 수: ${image.planes.length}');
  return null;
}
```

#### 회전 정보 계산 실패
```dart
// 디바이스 방향이 null인 경우 처리
var rotationCompensation = _orientations[controller.value.deviceOrientation];
if (rotationCompensation == null) {
  print('디바이스 방향을 확인할 수 없습니다');
  return null;
}
```

### 디버깅 팁
- **Google의 네이티브 예제 앱**으로 먼저 테스트
- **플랫폼별 로그** 확인 (Android: adb logcat, iOS: Xcode Console)  
- **이미지 포맷과 회전 정보** 검증
- **InputImage 메타데이터** 정확성 확인
- **카메라 권한과 초기화** 상태 점검

### 플랫폼별 이슈 해결

#### Android 특화 문제
- **Gradle 버전 호환성:** compileSdkVersion 35 사용 권장
- **ProGuard 설정:** ML Kit 클래스 난독화 제외 필요시
- **메모리 사용량:** 대용량 이미지 처리 시 OutOfMemory 주의

#### iOS 특화 문제  
- **Pod 설치 실패:** `pod install --repo-update` 실행
- **시뮬레이터 제한:** 실제 기기에서 테스트 권장
- **메모리 관리:** ARC와 Flutter의 메모리 관리 충돌 주의

## 관련 링크

### 패키지
- [google_mlkit_face_detection](https://pub.dev/packages/google_mlkit_face_detection) - 얼굴 감지 패키지
- [google_mlkit_commons](https://pub.dev/packages/google_mlkit_commons) - 공통 유틸리티 패키지

### GitHub 저장소  
- [Google ML Kit Flutter](https://github.com/flutter-ml/google_ml_kit_flutter) - 전체 프로젝트
- [Face Detection 패키지](https://github.com/flutter-ml/google_ml_kit_flutter/tree/master/packages/google_mlkit_face_detection)
- [Commons 패키지](https://github.com/flutter-ml/google_ml_kit_flutter/tree/master/packages/google_mlkit_commons)

### 예제 및 문서
- [Face Detection 예제](https://github.com/flutter-ml/google_ml_kit_flutter/tree/master/packages/google_mlkit_face_detection/example)
- [Commons 예제](https://github.com/flutter-ml/google_ml_kit_flutter/tree/master/packages/google_mlkit_commons/example)
- [Google ML Kit 공식 문서](https://developers.google.com/ml-kit/vision/face-detection)
- [Flutter Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels)

## 라이선스

MIT License - 자세한 내용은 패키지 페이지를 참조하세요.