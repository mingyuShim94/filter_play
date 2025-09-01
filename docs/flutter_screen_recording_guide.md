# Flutter setState 독립적 고성능 스크린 레코딩 시스템 구현 가이드

## 개요

Flutter에서 `setState`가 빈번하게 발생하는 환경에서도 안정적으로 특정 위젯을 고정 FPS로 캡쳐하고 영상으로 변환하는 시스템을 구현하는 방법을 정리한 가이드입니다.

### 핵심 도전과제

- `setState` 호출로 인한 불필요한 위젯 재빌드가 캡쳐 성능에 미치는 영향
- 안정적인 20fps 캡쳐 유지
- 모바일 환경에서의 메모리 효율적인 영상 처리
- 플랫폼별 최적화 (iOS/Android)

### 해결 전략

1. **상태 관리 분리**: `ValueNotifier` + `ValueListenableBuilder`로 효율적 업데이트
2. **렌더링 격리**: `RepaintBoundary`로 캡쳐 영역 독립화
3. **타이밍 최적화**: `Timer.periodic` + `addPostFrameCallback` 조합
4. **데이터 포맷 최적화**: Raw RGBA 직접 처리로 중간 변환 생략
5. **영상 처리 파이프라인**: FFmpeg 하드웨어 가속 활용

---

## 핵심 기술 스택

### 1. RepaintBoundary

```dart
RepaintBoundary(
  key: _globalKey,
  child: YourCaptureWidget(),
)
```

- **목적**: 캡쳐 대상 위젯을 별도 레이어로 격리
- **효과**: 전체 위젯 트리 재빌드와 무관하게 캡쳐 영역만 독립적으로 렌더링

### 2. ValueNotifier + ValueListenableBuilder

```dart
final ValueNotifier<List<int>> stateNotifier = ValueNotifier<List<int>>([]);

ValueListenableBuilder<List<int>>(
  valueListenable: stateNotifier,
  builder: (context, state, child) {
    return YourWidget(state: state);
  },
)
```

- **목적**: `setState` 대신 사용하여 필요한 위젯만 업데이트
- **효과**: 전체 위젯 트리 재빌드 방지, 성능 최적화

### 3. Timer.periodic + addPostFrameCallback

```dart
Timer.periodic(Duration(milliseconds: 50), (timer) {
  if (mounted) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _captureFrame();
    });
  }
});
```

- **목적**: 정확한 20fps(50ms 간격) 캡쳐
- **효과**: 렌더링 완료 후 안전한 캡쳐 타이밍 보장

---

## 개발 과정에서의 시행착오와 해결책

### 1. 캡쳐 형식 선택 문제

#### ❌ 초기 접근 (PNG 형식)

```dart
final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
```

**문제점:**

- PNG 인코딩/디코딩 오버헤드
- FFmpeg에서 다시 디코딩 필요
- 파일 크기 증가로 I/O 부담

#### ✅ 최적화된 접근 (Raw RGBA)

```dart
final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
```

**장점:**

- 중간 변환 과정 생략
- FFmpeg 직접 처리 가능
- 메모리 효율성 향상

### 2. FFmpeg 명령어 실행 오류

#### ❌ 잘못된 접근

```dart
final session = await FFmpegKit.execute('ffmpeg $command');
```

**오류:** `Unable to choose an output format for 'ffmpeg'`
**원인:** FFmpegKit이 이미 ffmpeg를 실행하므로 이중 prefix 발생

#### ✅ 올바른 접근

```dart
final session = await FFmpegKit.execute(command);
```

**해결:** FFmpegKit은 자동으로 ffmpeg를 호출하므로 prefix 불필요

### 3. 프레임 순서 보장 문제

#### ❌ 타임스탬프 기반 파일명

```dart
final fileName = 'frame_${DateTime.now().millisecondsSinceEpoch}.raw';
```

**문제:** 파일 생성 순서와 실제 순서 불일치 가능

#### ✅ 제로 패딩된 순차 번호

```dart
final frameNumber = _frameCount.toString().padLeft(6, '0');
final fileName = 'frame_$frameNumber.raw';
```

**해결:** 파일명 정렬로 정확한 순서 보장

---

## 성능 최적화 전략

### 1. 상태 관리 최적화

```dart
// setState 대신 ValueNotifier 사용
final ValueNotifier<List<int>> filledButtonsNotifier = ValueNotifier<List<int>>([]);

// 상태 변경 시
filledButtonsNotifier.value = updatedList; // 해당 위젯만 재빌드
```

### 2. 메모리 관리

```dart
// 대용량 Raw 파일들을 하나로 통합하여 I/O 최적화
final sink = concatenatedFile.openWrite();
for (final file in rawFiles) {
  final bytes = await file.readAsBytes();
  sink.add(bytes);
}
await sink.close();

// 처리 완료 후 임시 파일 정리
await _cleanupRawFrames();
```

### 3. 플랫폼별 FFmpeg 최적화

```dart
// iOS: 하드웨어 가속 활용
final videoEncoder = Platform.isIOS ? 'h264_videotoolbox' : 'libx264';

final videoOutput = Platform.isIOS
  ? '-c:v $videoEncoder -realtime 1 -pix_fmt yuv420p'
  : '-c:v $videoEncoder -preset ultrafast -crf 28 -pix_fmt yuv420p';
```

---

## 완전한 구현 템플릿

### 필수 의존성 (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  ffmpeg_kit_flutter_new: ^3.2.0
  path_provider: ^2.1.5
  path: ^1.9.0
```

### 핵심 상태 관리 변수들

```dart
class _ScreenRecorderState extends State<ScreenRecorder> {
  final GlobalKey _globalKey = GlobalKey();
  Timer? _captureTimer;

  // 캡쳐 관련 상태
  final ValueNotifier<bool> _isRecordingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> _frameCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<double> _actualFpsNotifier = ValueNotifier<double>(0.0);

  // 영상 처리 상태
  final ValueNotifier<bool> _isProcessingVideoNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> _processingStatusNotifier = ValueNotifier<String>('');
  final ValueNotifier<String> _finalVideoPathNotifier = ValueNotifier<String>('');

  // 세션 관리
  DateTime? _recordingStartTime;
  DateTime? _recordingEndTime;
  Directory? _sessionDirectory;
  Size? _frameSize;

  // FPS 계산
  DateTime? _lastCaptureTime;
  final List<Duration> _captureDurations = [];
}
```

### 캡쳐 시스템 구현

```dart
Future<void> _captureFrame() async {
  if (_globalKey.currentContext == null || _sessionDirectory == null) return;

  try {
    // FPS 계산
    final now = DateTime.now();
    if (_lastCaptureTime != null) {
      final duration = now.difference(_lastCaptureTime!);
      _captureDurations.add(duration);

      if (_captureDurations.length > 10) {
        _captureDurations.removeAt(0);
      }

      final avgDuration = _captureDurations.fold<int>(0, (sum, d) => sum + d.inMilliseconds) / _captureDurations.length;
      _actualFpsNotifier.value = 1000 / avgDuration;
    }
    _lastCaptureTime = now;

    // RepaintBoundary에서 이미지 캡쳐
    final RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 1.0);

    // 프레임 크기 저장 (최초 1회만)
    if (_frameSize == null) {
      _frameSize = Size(image.width.toDouble(), image.height.toDouble());
    }

    // Raw RGBA 형식으로 변환
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final Uint8List? rawBytes = byteData?.buffer.asUint8List();

    if (rawBytes != null) {
      await _saveRawFrame(rawBytes);
      _frameCountNotifier.value = _frameCountNotifier.value + 1;
    }
  } catch (e) {
    debugPrint('캡쳐 실패: $e');
  }
}
```

---

## 트러블슈팅 가이드

### 자주 발생하는 문제들

#### 1. FFmpeg "Unable to choose an output format" 오류

**원인:** FFmpegKit.execute()에 'ffmpeg' prefix 이중 사용
**해결:**

```dart
// ❌ 잘못된 방법
await FFmpegKit.execute('ffmpeg $command');

// ✅ 올바른 방법
await FFmpegKit.execute(command);
```

#### 2. 캡쳐 실패 또는 빈 프레임

**원인:** addPostFrameCallback 없이 렌더링 중 캡쳐 시도
**해결:**

```dart
Timer.periodic(Duration(milliseconds: 50), (timer) {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _captureFrame(); // 렌더링 완료 후 캡쳐
  });
});
```

#### 3. 메모리 부족 문제

**원인:** 대량의 Raw 프레임 파일 누적
**해결:**

```dart
// 영상 생성 완료 후 즉시 Raw 파일들 정리
await _cleanupRawFrames();
```

#### 4. FPS 불안정

**원인:** UI 업데이트와 캡쳐 타이밍 충돌
**해결:**

```dart
// ValueNotifier 사용으로 불필요한 재빌드 방지
ValueListenableBuilder<T>(
  valueListenable: notifier,
  builder: (context, value, child) => Widget(),
)
```

---

## 확장 응용 방법

### 다른 위젯 타입으로 적용

- **차트/그래프**: 실시간 데이터 시각화 캡쳐
- **게임 화면**: 게임 플레이 영상 녹화
- **커스텀 애니메이션**: 애니메이션 시퀀스 캡쳐

### 성능 조정 옵션

```dart
// FPS 조정 (20fps → 30fps)
Timer.periodic(Duration(milliseconds: 33), ...);

// 해상도 조정
final ui.Image image = await boundary.toImage(pixelRatio: 2.0); // 고해상도

// 압축 설정 조정 (Android)
'-crf 28' // 낮을수록 고품질 (18-28 권장)
```

### 추가 기능 확장

- **오디오 녹음**: 마이크 입력과 동기화
- **실시간 스트리밍**: RTMP 프로토콜로 라이브 방송
- **다중 영역 캡쳐**: 여러 RepaintBoundary 동시 캡쳐

---

## 핵심 교훈

### 1. 라이브러리 정확한 사용법 숙지

- FFmpegKit, Camera, ML Kit 등의 공식 문서 숙독 필수
- 예제 코드와 실제 프로덕션 사용법의 차이 이해

### 2. 성능 우선 설계

- 초기부터 성능을 고려한 아키텍처 설계
- 중간 포맷 변환 최소화
- 메모리 사용량 지속적 모니터링

### 3. 플랫폼별 최적화 필수

- iOS: 하드웨어 가속 VideoToolbox 활용
- Android: 소프트웨어 인코딩 속도 최적화
- 테스트 환경과 실제 기기 성능 차이 고려

### 4. 단계적 개발 접근

1. **기본 캡쳐** → 2. **상태 관리 최적화** → 3. **영상 처리 추가** → 4. **성능 튜닝**
2. 각 단계별로 충분한 테스트 후 다음 단계 진행

---

## 체크리스트

### 구현 전 확인사항

- [ ] 필요한 의존성 추가 완료
- [ ] 대상 위젯 RepaintBoundary로 감싸기
- [ ] ValueNotifier 기반 상태 관리 설계
- [ ] 플랫폼별 권한 설정 (카메라, 저장소)

### 구현 중 확인사항

- [ ] Timer 정리 (dispose에서 cancel)
- [ ] ValueNotifier 정리 (dispose에서 dispose)
- [ ] 메모리 누수 방지
- [ ] 오류 처리 및 사용자 피드백

### 테스트 항목

- [ ] 다양한 기기에서 성능 확인
- [ ] 장시간 녹화 시 메모리 사용량
- [ ] 백그라운드 전환 시 동작
- [ ] 권한 거부 시 처리

---

## 성능 벤치마크 가이드

### 측정 지표

- **실제 FPS**: 목표 vs 실제 달성 FPS
- **메모리 사용량**: Raw 파일 크기 vs 최종 영상 크기
- **처리 시간**: 캡쳐 → 영상 변환 총 소요 시간
- **CPU 사용률**: 인코딩 중 CPU 점유율

### 최적화 기준

- **FPS 안정성**: 목표 FPS의 95% 이상 유지
- **메모리 효율**: Raw 데이터 → 최종 영상 압축률 10:1 이상
- **처리 속도**: 실시간 대비 2x 이하 처리 시간

---

## 참고 자료

### 공식 문서

- [Flutter RepaintBoundary](https://api.flutter.dev/flutter/widgets/RepaintBoundary-class.html)
- [FFmpeg Kit Flutter](https://pub.dev/packages/ffmpeg_kit_flutter)
- [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html)

### 관련 기술

- **ML Kit 연동**: 얼굴 인식과 캡쳐 동기화
- **Camera Plugin**: 실시간 카메라 피드 캡쳐
- **Flame Engine**: 게임 엔진과 캡쳐 시스템 통합

---

## 결론

이 가이드에서 제시한 접근법을 사용하면 Flutter에서 `setState`의 영향을 받지 않는 안정적이고 고성능인 스크린 레코딩 시스템을 구현할 수 있습니다. 핵심은 **상태 관리 분리**, **렌더링 격리**, **최적화된 데이터 파이프라인**의 조합입니다.

특히 모바일 환경의 제약된 리소스에서도 원활하게 동작하도록 메모리 효율성과 플랫폼별 최적화를 고려한 설계가 중요합니다.
