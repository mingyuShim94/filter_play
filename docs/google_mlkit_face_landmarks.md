# Google ML Kit Face Detection 랜드마크 조사 결과

## 개요

Google ML Kit Face Detection 패키지(`google_mlkit_face_detection`)에서 제공하는 얼굴 랜드마크 기능에 대한 조사 결과입니다.

## 패키지 정보

- **패키지명**: `google_mlkit_face_detection`
- **플랫폼 지원**: Android, iOS
- **주요 기능**: 얼굴 감지, 얼굴 랜드마크 검출, 윤곽선 감지

## FaceLandmarkType 전체 목록

Google ML Kit Face Detection에서 지원하는 얼굴 랜드마크는 총 **9개**입니다:

### 👁️ 눈 랜드마크 (2개)
- **LEFT_EYE** - 좌측 눈의 중심점 (눈동자 중앙)
- **RIGHT_EYE** - 우측 눈의 중심점 (눈동자 중앙)

### 👂 귀 랜드마크 (2개)
- **LEFT_EAR** - 좌측 귀의 끝부분과 귓볼 사이의 중점
- **RIGHT_EAR** - 우측 귀의 끝부분과 귓볼 사이의 중점

### 😊 볼 랜드마크 (2개)
- **LEFT_CHEEK** - 좌측 입꼬리와 좌측 눈 바깥쪽 모서리 사이의 중점
- **RIGHT_CHEEK** - 우측 입꼬리와 우측 눈 바깥쪽 모서리 사이의 중점

### 👃 코 랜드마크 (1개)
- **NOSE_BASE** - 콧구멍 사이의 중점 (코와 얼굴이 만나는 지점)

### 👄 입 랜드마크 (3개)
- **MOUTH_LEFT** - 좌측 입꼬리 (입술이 만나는 지점)
- **MOUTH_RIGHT** - 우측 입꼬리 (입술이 만나는 지점)
- **MOUTH_BOTTOM** - 아래 입술의 중심점

## 랜드마크 특징 및 제약사항

### 좌표계
- 좌표 원점: 이미지의 왼쪽 상단 (0, 0)
- 반환 타입: `Point<int>` 형태의 2D 좌표
- 좌표는 항상 이미지 경계 내에서 제공됨

### 방향성 고려사항
- 'left'와 'right'는 이미지의 주체(얼굴) 기준
- 예: LEFT_EYE는 얼굴 주인의 왼쪽 눈 (이미지를 보는 관찰자 기준이 아님)
- 얼굴의 각도(Euler Y angle)에 따라 감지 가능한 랜드마크가 달라질 수 있음

### 활성화 조건
- 랜드마크 검출을 위해 `FaceDetectorOptions` 설정 필요:
```dart
final options = FaceDetectorOptions(
  enableLandmarks: true, // 또는 landmarkMode: FaceDetectorOptions.LANDMARK_MODE_ALL
);
```

## 사용 예시

```dart
// 얼굴 감지 및 랜드마크 추출
final List<Face> faces = await faceDetector.processImage(inputImage);

for (Face face in faces) {
  // 특정 랜드마크 접근
  final FaceLandmark? leftEye = face.landmarks[FaceLandmarkType.leftEye];
  if (leftEye != null) {
    final Point<int> leftEyePos = leftEye.position;
    print('왼쪽 눈 위치: (${leftEyePos.x}, ${leftEyePos.y})');
  }
  
  // 모든 랜드마크 순회
  face.landmarks.forEach((landmarkType, landmark) {
    final position = landmark.position;
    print('${landmarkType}: (${position.x}, ${position.y})');
  });
}
```

## 활용 가능 분야

1. **얼굴 분석**: 얼굴 특징점 분석 및 측정
2. **AR 필터**: 실시간 얼굴 추적을 통한 증강현실 효과
3. **얼굴 인식**: 얼굴 특징점 기반 인증 시스템
4. **표정 분석**: 입과 눈의 위치 변화를 통한 감정 분석
5. **얼굴 보정**: 사진 편집 시 얼굴 특징점 기반 자동 보정

## 참고사항

- Face Mesh Detection과는 다른 기능 (Face Mesh는 더 세밀한 468개 포인트 제공)
- 실시간 처리 시 성능 최적화 필요
- 조명 조건과 얼굴 각도에 따라 정확도 변동 가능
- iOS는 15.5 이상, Android는 minSdkVersion 21 이상 필요

---

*조사일: 2025-08-07*  
*패키지 버전: google_mlkit_face_detection (latest)*