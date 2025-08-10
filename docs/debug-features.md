# 디버깅 기능 참조 가이드

이 문서는 개발 중 비활성화된 디버깅 기능들과 재활성화 방법을 정리합니다.

## 🎛️ 디버깅 플래그 위치

### 1. FaceDetectionOverlay
**파일**: `lib/widgets/face_detection_overlay.dart`
```dart
// 디버깅 표시 활성화 플래그 (개발 시에만 true로 설정)
static const bool _showDebugOverlay = false; // ← 이 값을 true로 변경
```

### 2. CameraScreen
**파일**: `lib/screens/camera_screen.dart`
```dart
// 디버깅 표시 활성화 플래그 (개발 시에만 true로 설정)
static const bool _showDebugInfo = false; // ← 이 값을 true로 변경
```

## 📊 비활성화된 디버깅 기능들

### FaceDetectionOverlay 디버깅 표시

#### 얼굴 Bounding Box
- **설명**: 감지된 얼굴 영역을 녹색 테두리로 표시
- **색상**: 녹색 (Colors.green)
- **두께**: 2.0px

#### 얼굴 랜드마크 점
- **일반 랜드마크**: 파란색 원형 점 (반지름 4.0px)
  - 왼쪽/오른쪽 눈
  - 코 기저부
  - 왼쪽/오른쪽 귀
  - 왼쪽/오른쪽 볼
- **입술 랜드마크**: 빨간색 원형 점 (반지름 6.0px)
  - 왼쪽/오른쪽 입꼬리
  - 아래 입술

#### 입술 중심점
- **윗입술 중심**: 노란색 원형 점 (반지름 5.0px)
- **입술 전체 중심**: 보라색 원형 점 (반지름 7.0px)

#### 얼굴 개수 표시
- **위치**: 화면 좌상단
- **내용**: "감지된 얼굴: N개"
- **스타일**: 녹색 배경, 흰색 텍스트

#### Face 텍스트 레이블
- **위치**: 각 얼굴 bounding box 상단
- **내용**: "Face"
- **스타일**: 녹색 텍스트, 검은색 반투명 배경

### CameraScreen 디버깅 오버레이

#### 이마 사각형 상태 정보
- **위치**: 화면 우상단 (top: 50, right: 20)
- **배경**: 청록색 (Colors.cyan) 반투명 박스
- **내용**:
  - 제목: "이마 사각형"
  - 중심 좌표: "(x, y)"
  - 크기: "width × height"
  - Y축 회전: "rotY: N°"
  - Z축 회전: "rotZ: N°" 
  - 스케일: "scale: N.NN"
  - 이미지 상태: "로딩됨" / "없음"

#### 입술 데이터 정보
- **위치**: 화면 우상단 (top: 180, right: 20)
- **배경**: 보라색 (Colors.purple) 반투명 박스
- **내용**:
  - 제목: "T2C.4: 입술 상태"
  - 입술 높이: "높이: N.Npx"
  - 입술 너비: "너비: N.Npx"
  - 정규화 높이: "정규화 H: N.NNNN"
  - 정규화 너비: "정규화 W: N.NNN"
  - 개방률: "개방률: N.NNN"
  - 상태: "OPEN" / "CLOSED" / "UNKNOWN"
  - 캘리브레이션 정보

#### 얼굴 인식 상태 오버레이
- **위치**: 화면 상단 중앙 (top: 20)
- **배경**: 검은색 반투명 박스
- **내용**:
  - 얼굴 인식 상태 아이콘 및 텍스트
  - 카메라 방향 표시 (전면/후면)
  - 얼굴 감지 안내 메시지
  - 감지된 얼굴 개수

#### 성능 메트릭 오버레이
- **위치**: 화면 우상단
- **컴포넌트**: `PositionedPerformanceOverlay`
- **내용**: 성능 관련 수치 및 메트릭

## 🔄 재활성화 방법

### 전체 디버깅 활성화
1. `FaceDetectionOverlay`의 `_showDebugOverlay`를 `true`로 설정
2. `CameraScreen`의 `_showDebugInfo`를 `true`로 설정
3. 앱 재빌드 (`flutter hot restart` 권장)

### 부분 디버깅 활성화
특정 기능만 확인하려면 해당 플래그만 활성화

### 코드 예시
```dart
// 얼굴 랜드마크와 bounding box만 확인
static const bool _showDebugOverlay = true;  // FaceDetectionOverlay에서
static const bool _showDebugInfo = false;    // CameraScreen에서

// 상태 정보만 확인  
static const bool _showDebugOverlay = false; // FaceDetectionOverlay에서
static const bool _showDebugInfo = true;     // CameraScreen에서
```

## 📝 개발 팁

### 성능 최적화 시
- `_showDebugInfo = true`로 설정하여 성능 메트릭 확인
- FPS, 메모리 사용량, 얼굴 감지 시간 모니터링

### 얼굴 감지 문제 해결 시
- `_showDebugOverlay = true`로 설정
- Bounding box와 랜드마크 위치 확인
- 좌표 변환 문제 디버깅

### 입술 추적 개발 시
- 두 플래그 모두 `true`로 설정
- 입술 랜드마크와 중심점 시각화
- 상태 전환 및 캘리브레이션 과정 모니터링

## ⚠️ 주의사항

- 디버깅 플래그는 `const` 선언되어 있어 핫 리로드로 변경되지 않음
- 플래그 변경 후 반드시 **Hot Restart** (`Ctrl+Shift+F5`) 실행
- 프로덕션 빌드 시 반드시 `false`로 설정 확인
- 디버깅 정보는 성능에 영향을 줄 수 있으므로 개발 시에만 활성화