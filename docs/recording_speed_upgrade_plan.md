안녕하세요! 제공해주신 Flutter 코드에서 영상 합성 시간을 단축하는 방법에 대해 분석하고 해결책을 제시해 드리겠습니다.

현재 코드의 영상 합성 과정은 다음과 같은 단계로 이루어집니다.

1.  **프레임 캡처:** 녹화 중 `RepaintBoundary`를 사용해 화면을 20fps로 캡처하여 수많은 개별 Raw RGBA 이미지 파일(`frame_xxxx.raw`)로 저장합니다.
2.  **프레임 병합:** 녹화가 끝나면 저장된 모든 개별 `.raw` 파일을 다시 읽어 하나의 거대한 `video.raw` 파일로 합칩니다.
3.  **FFmpeg 실행:** 병합된 `video.raw` 파일과 녹음된 `audio.m4a` 파일을 입력으로 사용하여 FFmpeg로 최종 `mp4` 영상을 인코딩합니다.

이 과정에서 가장 시간이 많이 소요되는 두 가지 병목 지점은 다음과 같습니다.

- **I/O 병목:** 수백, 수천 개의 작은 파일을 디스크에 쓰고, 녹화가 끝난 후 다시 모든 파일을 읽어 하나의 파일로 합치는 과정은 매우 비효율적이며 많은 시간을 소모합니다.
- **CPU 병목:** FFmpeg가 거대한 Raw RGBA 데이터를 처리하고, 프레임 크기를 조절하며, H.264 코덱으로 압축하는 과정은 CPU를 많이 사용합니다.

이 문제들을 해결하고 영상 합성 시간을 획기적으로 단축할 수 있는 몇 가지 방법을 제안합니다.

---

### 해결 방안 1: 실시간 프레임 스트리밍으로 I/O 병목 제거 (가장 효과적)

녹화 중에 개별 파일을 생성하는 대신, 단일 파일 스트림을 열어두고 캡처된 프레임 데이터를 즉시 추가하는 방식입니다. 이렇게 하면 파일 생성/읽기/병합 과정이 완전히 사라져 I/O 관련 시간 소모가 거의 없어집니다.

**코드 수정:**

1.  **`_RankingFilterScreenState`에 `IOSink` 변수 추가**

    ```dart
    // ...
    int _skippedFrames = 0;
    bool _isCapturingFrame = false;
    IOSink? _recordingSink; // 녹화 파일 스트림을 위한 변수 추가
    String? _rawVideoPath;   // Raw 비디오 파일 경로 저장 변수 추가

    @override
    // ...
    ```

2.  **`_startRecording()` 수정: 파일 스트림 열기**

    ```dart
    Future<void> _startRecording() async {
      // ... (권한 확인)

      // ... (상태 설정)

      try {
        // ... (세션 디렉토리 생성)

        // 🚀 [개선] 단일 Raw 비디오 파일 스트림 열기
        _rawVideoPath = '${_sessionDirectory!.path}/video.raw';
        _recordingSink = File(_rawVideoPath!).openWrite();

        // ... (오디오 녹음 시작)

        _frameCaptureTimer = Timer.periodic(
          Duration(microseconds: (1000000 / 20).round()),
          (timer) => _captureFrameForRecording(),
        );
      } catch (e) {
        // ... (에러 처리)
      }
    }
    ```

3.  **`_captureFrameForRecording()` 수정: 파일에 쓰지 않고 스트림에 추가**

    ```dart
    Future<void> _captureFrameForRecording() async {
      // ...
      try {
        // ... (ui.Image 캡처)

        ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);

        if (byteData != null) {
          Uint8List rawBytes = byteData.buffer.asUint8List();

          // 🚀 [개선] 개별 파일 저장 대신, 열려있는 스트림에 데이터 추가
          _recordingSink?.add(rawBytes);

          if (mounted) {
            setState(() {
              _frameCount++;
            });
          }
          // ... (성능 분석 로그)
        }
        image.dispose();
      } catch (e) {
        print('RawRGBA 프레임 캡처 오류: $e');
      } finally {
        _isCapturingFrame = false;
      }
    }
    ```

4.  **`_stopRecording()` 수정: 파일 스트림 닫기**

    ```dart
    Future<void> _stopRecording() async {
      _recordingEndTime = DateTime.now();

      setState(() {
        _isRecording = false;
        _isProcessing = true;
        _statusText = '녹화 완료, 동영상 합성 준비 중...';
      });

      try {
        _frameCaptureTimer?.cancel();
        _frameCaptureTimer = null;

        // 🚀 [개선] 녹화 스트림 닫기
        await _recordingSink?.close();
        _recordingSink = null;

        await _audioRecorder.stop();
        await _composeVideo();
      } catch (e) {
        // ... (에러 처리)
      }
    }
    ```

5.  **`_composeVideo()` 수정: 프레임 병합 로직 제거**
    이제 `_composeVideo` 함수 내에서 Raw 파일들을 찾아 병합하는 반복문이 필요 없습니다.

    ```dart
    // 3. 모든 Raw 프레임을 하나의 파일로 합치기 -> 🚀 [제거] 이 단계 전체가 불필요해짐
    // setState(() {
    //   _statusText = 'Raw 프레임 병합 중...';
    // });
    // final concatenatedRawPath = '${_sessionDirectory!.path}/video.raw'; // _rawVideoPath 변수 사용
    // ... (반복문으로 파일 합치는 부분 모두 삭제)
    ```

### 해결 방안 2: 하드웨어 가속 인코딩 활용 (CPU 사용량 감소)

대부분의 최신 스마트폰에는 비디오 인코딩을 위한 전용 하드웨어(HW)가 탑재되어 있습니다. FFmpeg가 이 하드웨어를 사용하도록 설정하면 CPU를 사용하는 소프트웨어(SW) 인코딩보다 훨씬 빠르게 영상을 처리할 수 있습니다.

**`_composeVideo()` 함수 수정:**

```dart
Future<void> _composeVideo() async {
  try {
    // ... (실제 FPS 계산)

    // ... 🚀 [수정] Raw 파일 검색 및 병합 로직은 이미 제거됨

    final firstFileName = ... // 해상도 감지 로직은 그대로 유지
    final videoSize = match.group(1)!;
    print('🎬 해상도 감지: $videoSize');

    // 🚀 [추가] 플랫폼에 맞는 하드웨어 가속 코덱 선택
    String videoCodec;
    String pixelFormat = 'yuv420p'; // 호환성을 위해 yuv420p 사용 권장
    if (Platform.isIOS) {
      // iOS: VideoToolbox 사용
      videoCodec = 'h264_videotoolbox';
    } else { // Android
      // Android: MediaCodec 사용
      videoCodec = 'h264_mediacodec';
    }
    print('🎬 하드웨어 가속 코덱 사용: $videoCodec');

    final concatenatedRawPath = _rawVideoPath; // _startRecording에서 설정한 경로
    if (concatenatedRawPath == null || !File(concatenatedRawPath).existsSync()) {
      throw Exception('녹화된 Raw 비디오 파일이 없습니다.');
    }

    // ... (FFmpeg 명령어 구성)
    final outputPath = ...;
    final audioPath = ...;

    String command;
    final videoInput =
        '-f rawvideo -pixel_format rgba -video_size $videoSize -framerate ${actualFps.toStringAsFixed(2)} -i "$concatenatedRawPath"';
    final audioFilter = '-af "volume=2.5"';

    // 🚀 [수정] videoOutput 부분에 하드웨어 코덱 적용
    final videoOutput =
        '-c:v $videoCodec -pix_fmt $pixelFormat -preset ultrafast -vf "scale=360:696"';

    // ... (나머지 명령어 조합 및 실행 로직은 동일)

  } catch (e) {
    // ... (에러 처리)
  }
}
```

### 해결 방안 3: 캡처 해상도 최적화 (데이터 처리량 감소)

현재 코드는 `devicePixelRatio`를 그대로 사용하여 기기의 최대 해상도로 화면을 캡처하고 있습니다. 하지만 최종 결과물은 `360x696`으로 크게 축소됩니다. 캡처 단계에서부터 해상도를 낮추면 처리해야 할 데이터의 총량이 줄어들어 모든 과정(I/O, CPU 처리)이 빨라집니다.

**`_captureFrameForRecording()` 함수 수정:**

```dart
// ...
// RawRGBA 고해상도 캡처: devicePixelRatio 적용으로 물리적 픽셀 해상도 사용
// 🚀 [수정] pixelRatio를 1.0 또는 1.5 정도로 낮춰 데이터 양을 줄임
ui.Image image = await boundary.toImage(pixelRatio: 1.5); // 1.0 ~ 1.5 권장

// RawRGBA 포맷으로 변환 (압축 없음, 고속 처리)
ByteData? byteData =
    await image.toByteData(format: ui.ImageByteFormat.rawRgba);
// ...
```

`pixelRatio`를 1.0으로 설정하면 논리적 픽셀 크기로 캡처하게 되어 데이터 양이 크게 줄어듭니다. 최종 화질을 확인하며 적절한 값(e.g., 1.5)으로 조절할 수 있습니다.

### 요약

위 세 가지 해결 방안을 모두 적용하면 영상 합성 시간을 크게 단축할 수 있습니다.

1.  **실시간 스트리밍 (`IOSink`)**으로 불필요한 파일 읽기/쓰기/병합 작업을 제거합니다. (가장 큰 성능 향상)
2.  **하드웨어 가속 (`h264_videotoolbox`, `h264_mediacodec`)**을 사용하여 CPU 부담을 줄이고 인코딩 속도를 높입니다.
3.  **캡처 해상도 최적화 (`pixelRatio` 조정)**로 처리할 데이터의 총량을 줄여 전반적인 처리 속도를 향상시킵니다.
