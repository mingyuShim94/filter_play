# 프레임 캡처 및 영상 변환 최적화 가이드

## 📌 개요

Flutter 앱에서 실시간 화면 캡처를 통한 영상 녹화 시스템의 성능 최적화 과정과 해결 방법들을 정리합니다.

## 🎯 프로젝트 목표

- **실시간 화면 캡처**: RepaintBoundary를 이용한 프레임 수집
- **오디오-비디오 동기화**: FFmpeg를 통한 영상 합성
- **안정적인 성능**: 프레임 손실 최소화 및 일관된 품질

## 🚨 발견된 주요 문제들

### 0. FFmpeg 기본 합성 에러들

#### A. 프레임 파일 인식 실패
**증상**: `No such file or directory` 에러
```bash
[image2 @ 0x...] Could not find codec parameters for stream 0
```

**원인**: 파일명 패딩 부족으로 FFmpeg가 시퀀스를 인식하지 못함
```dart
// 문제: 패딩 없음
'frame_1.png', 'frame_2.png', 'frame_10.png'

// 해결: 5자리 패딩
'frame_00001.png', 'frame_00002.png', 'frame_00010.png'
final fileName = 'frame_${(_frameCount + 1).toString().padLeft(5, '0')}.png';
```

#### B. 홀수 해상도 에러
**증상**: `width not divisible by 2` 에러
```
[libx264 @ 0x...] width not divisible by 2 (361x697)
```

**원인**: libx264는 짝수 해상도만 지원
**해결**: 강제로 짝수 해상도 사용 `scale=360:696`

#### C. `-shortest` 플래그 문제
**증상**: 비디오가 오디오보다 짧게 생성
**해결**: `-shortest` 제거하여 전체 길이 유지

### 0-2. 개발 과정에서 마주친 일반적인 에러들

#### A. Dart print 함수 재할당 에러
**증상**: `print` 함수를 직접 재할당하려다 컴파일 에러
```dart
// 에러: print 함수 직접 할당 불가
print = (message) => { /* 커스텀 로직 */ };
```

**해결**: `runZoned`와 `ZoneSpecification` 사용
```dart
runZoned(() {
  runApp(const ProviderScope(child: FilterPlayApp()));
}, zoneSpecification: ZoneSpecification(
  print: (Zone self, ZoneDelegate parent, Zone zone, String message) {
    if (message.contains('🎬')) {
      parent.print(zone, message);
    }
  },
));
```

#### B. Android BuildConfig 설정 에러
**증상**: `buildConfigField` 사용 시 빌드 실패
```
> Missing buildFeatures.buildConfig true
```

**해결**: `build.gradle`에 buildFeatures 추가
```gradle
android {
    buildFeatures {
        buildConfig true  // 이 설정 필요
    }
    
    buildTypes {
        debug {
            buildConfigField "boolean", "ENABLE_LOGGING", "false"
        }
    }
}
```

#### C. 이미지 포맷 불일치 에러
**증상**: `rawRgba` 포맷을 PNG 파일로 저장하려다 실패
```dart
// 에러: rawRgba는 PNG 형식이 아님
ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
final file = File('frame.png'); // PNG 확장자와 불일치
```

**해결**: 포맷과 확장자 일치시키기
```dart
// PNG 포맷 사용
ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
```

#### D. 변수 스코프 에러
**증상**: 함수 간 변수 접근 불가
```dart
// 에러: actualFps 변수가 다른 함수에서 정의됨
if (condition) {
  final actualFps = calculation();
}
// actualFps 사용 불가 (스코프 벗어남)
```

**해결**: 적절한 스코프에서 변수 선언
```dart
// 함수 시작 부분에서 선언
double actualFps = 24.0; // 기본값
if (condition) {
  actualFps = calculation(); // 재할당
}
// 이제 사용 가능
```

#### E. UI 오버플로우 에러
**증상**: 결과 화면에서 하단 오버플로우 발생
```
RenderFlex overflowed by XX pixels on the bottom
```

**해결**: 조건부 레이아웃과 Expanded 위젯 사용
```dart
// 비디오 전용 모드와 게임 결과 모드 분리
if (widget.isVideoOnlyMode) {
  return SizedBox(
    width: double.infinity,
    height: double.infinity,
    child: AspectRatio(/* 비디오만 표시 */),
  );
}
```

### 1. 영상 재생 속도 문제
**증상**: 녹화된 영상이 실제보다 빠르게 재생됨

**원인**:
- Timer 주기 부정확성: `Duration(milliseconds: (1000/24).round())` = 42ms (실제 24.39fps)
- FFmpeg 설정 불일치: 캡처 23.8fps vs FFmpeg 24fps 설정
- 결과: 1.008배 빠른 재생

**해결책**:
```dart
// 기존: 부정확한 밀리초 단위
Duration(milliseconds: (1000 / 24).round()) // 42ms

// 개선: 정확한 마이크로초 단위  
Duration(microseconds: (1000000 / 24).round()) // 41667μs

// 최종: 안정성을 위한 20fps
Duration(microseconds: (1000000 / 20).round()) // 50000μs
```

### 2. 심각한 프레임 손실 (72% 스킵)
**증상**: 24fps 목표 → 실제 6.25fps 캡처

**원인 분석**:
- RepaintBoundary.toImage() 성능 병목: 160ms+ 소요
- PNG 인코딩 오버헤드: CPU 집약적 처리
- 동기식 파일 I/O: 메인 스레드 블로킹
- GPU ↔ CPU 데이터 전송 지연

## 🚀 최적화 방법들

### 1. 해상도 최적화 (가장 효과적)
```dart
// 기존: 풀 해상도 캡처
ui.Image image = await boundary.toImage(pixelRatio: 1.0);

// 개선: 50% 해상도 (4배 성능 향상)
ui.Image image = await boundary.toImage(pixelRatio: 0.5);
```

**효과**: 해상도 1/4 감소 → 처리 시간 대폭 단축

### 2. 비동기 파일 저장
```dart
// 기존: 동기식 저장 (메인 스레드 블로킹)
await file.writeAsBytes(pngBytes);

// 개선: 비동기 저장
file.writeAsBytes(pngBytes).then((_) {
  // 완료 후 처리
}).catchError((error) {
  print('🎬 ❌ 프레임 저장 오류: $error');
});
```

### 3. FFmpeg 기본 설정 문제 해결

#### `-shortest` 플래그 문제
**증상**: 오디오보다 비디오가 짧게 생성됨
```dart
// 문제가 있던 명령어
'-framerate 24 -i "$framePath" -i "$audioPath" -shortest -c:v libx264'

// 해결: -shortest 제거하여 전체 길이 유지
'-framerate 24 -i "$framePath" -i "$audioPath" -c:v libx264'
```

#### 홀수/짝수 해상도 문제
**증상**: FFmpeg에서 홀수 해상도 처리 불가 에러
```
[libx264 @ 0x...] width not divisible by 2 (361x697)
```

**해결**: 짝수 해상도로 강제 조정
```dart
// 안전한 짝수 해상도 사용
command = '-framerate ${actualFps.toStringAsFixed(2)} -i "$framePath" '
          '-vf "scale=360:696" -c:v libx264 -pix_fmt yuv420p';
```

### 4. 동적 프레임레이트 계산
```dart
// 실제 캡처 성능을 반영한 FFmpeg 설정
final actualFps = _frameCount / actualRecordingSeconds;
command = '-framerate ${actualFps.toStringAsFixed(2)} -i "$framePath"';
```

### 5. 적응형 FPS 설정
```dart
// 24fps (42ms) → 20fps (50ms)로 안정성 확보
Duration(microseconds: (1000000 / 20).round())
```

## 📊 성능 모니터링 시스템

### 실시간 성능 측정
```dart
final captureStartTime = DateTime.now();
// ... 캡처 로직 ...
final captureDuration = captureEndTime.difference(captureStartTime).inMilliseconds;

// 컬러풀한 성능 로그
if (captureDuration > 60) {
  print('🎬 ⚠️  느린 캡처: ${captureDuration}ms (목표: 50ms)');
} else if (captureDuration > 50) {
  print('🎬 ⚡ 약간 지연: ${captureDuration}ms');
} else {
  print('🎬 ✅ 빠른 캡처: ${captureDuration}ms');
}
```

### 종합 성능 분석
```dart
print('🎬 ⏱️  실제 녹화 시간: ${actualRecordingDuration.inSeconds}초');
print('🎬 📹 캡처된 프레임 수: $_frameCount');
print('🎬 📊 실제 캡처 FPS: ${actualFps.toStringAsFixed(2)}');
print('🎬 ⚠️  스킵된 프레임 수: $_skippedFrames');
print('🎬 📉 프레임 손실률: ${(손실률).toStringAsFixed(1)}%');
```

## 🔍 로그 필터링 시스템

### 선택적 로그 출력
```dart
// main.dart - 녹화 관련 로그만 표시
runZoned(() {
  runApp(const ProviderScope(child: FilterPlayApp()));
}, zoneSpecification: ZoneSpecification(
  print: (Zone self, ZoneDelegate parent, Zone zone, String message) {
    if (message.contains('🎬')) {
      parent.print(zone, message);
    }
  },
));
```

## 📈 최적화 결과

| 항목 | 최적화 전 | 최적화 후 |
|------|-----------|-----------|
| **캡처 FPS** | 6.25fps | 18-20fps |
| **프레임 손실률** | 72% | 10% 이하 |
| **캡처 시간** | 160ms+ | 31-63ms |
| **영상 재생 속도** | 1.008배 빠름 | 정확 |

## 🛠️ 구현 핵심 코드

### 프레임 캡처 최적화
```dart
Future<void> _captureFrameForRecording() async {
  if (!mounted || _isCapturingFrame) {
    _skippedFrames++;
    return;
  }
  
  _isCapturingFrame = true;
  final captureStartTime = DateTime.now();
  
  try {
    RenderRepaintBoundary boundary = _captureKey.currentContext!
        .findRenderObject() as RenderRepaintBoundary;

    // 성능 최적화: 해상도 50% 감소
    ui.Image image = await boundary.toImage(pixelRatio: 0.5);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      Uint8List pngBytes = byteData.buffer.asUint8List();
      final fileName = 'frame_${(_frameCount + 1).toString().padLeft(5, '0')}.png';
      final file = File('${_sessionDirectory!.path}/$fileName');

      // 비동기 파일 저장
      file.writeAsBytes(pngBytes).then((_) {
        // 완료 처리
      }).catchError((error) {
        print('🎬 ❌ 프레임 저장 오류: $error');
      });

      if (mounted) {
        setState(() {
          _frameCount++;
        });
      }
    }
  } catch (e) {
    print('프레임 캡처 오류: $e');
  } finally {
    _isCapturingFrame = false;
  }
}
```

### FFmpeg 동적 설정
```dart
Future<void> _composeVideo() async {
  // 실제 FPS 계산
  double actualFps = 20.0;
  if (_recordingStartTime != null && _recordingEndTime != null) {
    final actualRecordingSeconds = _recordingEndTime!
        .difference(_recordingStartTime!)
        .inMilliseconds / 1000.0;
    actualFps = _frameCount / actualRecordingSeconds;
  }

  // 실제 FPS로 FFmpeg 명령어 생성
  final command = '-framerate ${actualFps.toStringAsFixed(2)} -i "$framePath" '
                  '-i "$audioPath" -vf "scale=360:696" '
                  '-c:v libx264 -c:a aac -pix_fmt yuv420p -preset ultrafast "$outputPath"';
}
```

## 🎯 권장사항

### 성능 우선순위
1. **해상도 최적화** (가장 큰 효과)
2. **비동기 I/O** (메인 스레드 보호)
3. **안정적인 FPS** (20fps 권장)
4. **동적 계산** (실제 성능 반영)

### 디버깅 팁
- 🎬 이모지로 녹화 관련 로그 식별
- 컬러 코딩으로 성능 수준 구분
- 실시간 프레임 손실률 모니터링
- 캡처 시간 분포 분석

### 주의사항
- **파일명 패딩**: FFmpeg 시퀀스 인식을 위해 5자리 패딩 필수
- **짝수 해상도**: libx264는 홀수 해상도 지원 안함 (360x696 권장)
- **-shortest 주의**: 오디오-비디오 길이 불일치 시 제거 필요
- **pixelRatio**: 0.5 이하로 낮추면 화질 저하
- **비동기 저장**: 파일 완료 확인 필요
- **Timer 여유**: 실제 캡처 시간보다 넉넉하게 설정
- **GPU 메모리**: 상태에 따른 성능 변동 고려

## 📚 관련 파일들

- `lib/screens/ranking_filter_screen.dart`: 메인 캡처 로직
- `lib/main.dart`: 로그 필터링 설정
- `lib/screens/result_screen.dart`: 영상 재생 화면
- `android/app/build.gradle`: 얼굴 인식 로그 억제

---

**작성일**: 2025-01-16  
**최종 수정**: 프레임 손실률 72% → 10% 이하로 개선 완료