### 문제 분석: 프레임 손실의 원인

디버그 콘솔 로그를 보면, 약 3.5초 동안 20fps로 녹화를 시도했을 때 예상 프레임 수는 70이지만 실제 캡처된 프레임은 45에 불과하여 약 34.3%의 프레임 손실이 발생했습니다. 이는 녹화된 영상이 오디오와 싱크가 맞지 않는 주된 원인이 됩니다.

프레임 손실의 주요 원인은 **`_captureFrameForRecording`** 메서드 내의 처리 과정이 다음 프레임 캡처 시간 (50ms) 내에 완료되지 못하기 때문입니다. 특히 다음 두 부분이 주된 병목 현상을 일으킬 가능성이 높습니다:

1.  **`boundary.toImage(pixelRatio: targetPixelRatio)`**: `RepaintBoundary`를 UI 이미지로 변환하는 과정은 CPU와 GPU에 상당한 부하를 줍니다. 특히 매 프레임마다 이 작업을 수행하는 것은 매우 비용이 큰 작업입니다.
2.  **`image.toByteData(format: ui.ImageByteFormat.rawRgba)` 및 파일 쓰기**: 캡처된 이미지를 Raw RGBA 형식으로 변환하고 파일 시스템에 쓰는 작업 역시 I/O 오버헤드를 발생시켜 지연을 유발할 수 있습니다.

### 해결 방안

이 문제를 해결하기 위해 여러 가지 접근 방식을 병행하여 적용하는 것이 좋습니다.

#### 1. **프레임 캡처 로직 최적화**

가장 먼저 `_captureFrameForRecording` 메서드의 부담을 줄여야 합니다.

- **해상도 동적 조절**: 현재 캡처 해상도가 '360x697'로 감지되었습니다. 이는 비교적 낮은 해상도이지만, `RepaintBoundary`의 `toImage` 메서드는 여전히 무거울 수 있습니다. 캡처 시 `pixelRatio`를 1.0으로 고정한 것은 좋은 시도이지만, 더 나아가 캡처하는 위젯 자체의 크기를 줄이는 것도 고려해볼 수 있습니다.
- **별도의 Isolate에서 파일 I/O 처리**: 이미지 데이터를 파일로 쓰는 작업은 메인 Isolate(UI 스레드)의 작업을 방해할 수 있습니다. 파일 쓰기 작업을 별도의 Isolate에서 처리하면 UI 스레드의 부하를 줄여 프레임 드랍을 완화할 수 있습니다.

  ```dart
  // _captureFrameForRecording 내에서
  ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData != null) {
    // 파일 쓰기 작업을 별도의 Isolate에 맡깁니다.
    await compute(_saveFrameToFile, {
      'bytes': byteData.buffer.asUint8List(),
      'path': '${_sessionDirectory!.path}/frame_${(_frameCount + 1).toString().padLeft(5, '0')}.raw',
      'width': image.width,
      'height': image.height
    });
    _frameCount++;
  }
  ```

  별도의 `_saveFrameToFile` 함수를 최상위 레벨이나 static 메서드로 정의해야 합니다.

  ```dart
  void _saveFrameToFile(Map<String, dynamic> args) {
    final file = File(args['path']);
    // 해상도 정보를 파일명에 포함시키는 것이 좋습니다.
    final newPath = file.path.replaceFirst('.raw', '_${args['width']}x${args['height']}.raw');
    File(newPath).writeAsBytesSync(args['bytes']);
  }
  ```

#### 2. **녹화 후 처리(Post-processing)를 통한 싱크 조절**

프레임 드랍이 불가피한 경우, 녹화가 끝난 후 FFmpeg를 사용하여 오디오와 비디오의 싱크를 맞출 수 있습니다.

- **가변 프레임률(VFR) 대신 고정 프레임률(CFR) 사용**: FFmpeg는 기본적으로 입력된 이미지 시퀀스를 고정 프레임률로 처리하려고 합니다. 실제 캡처된 프레임률(`actualFps`)을 사용하는 것은 좋은 접근입니다.
- **오디오 속도 조절**: 비디오의 전체 길이에 맞게 오디오의 속도를 조절하여 싱크를 맞출 수 있습니다. 이는 약간의 음성 변조를 일으킬 수 있지만, 싱크가 완전히 어긋나는 것보다는 나은 경험을 제공합니다.

  FFmpeg 명령어에 오디오 필터 `atempo`를 추가하여 속도를 조절할 수 있습니다.

  ```dart
  // _composeVideo 내에서
  final actualRecordingSeconds = actualRecordingDuration.inMilliseconds / 1000.0;
  final videoDuration = _frameCount / actualFps;

  // 오디오 길이를 비디오 길이에 맞추기 위한 속도 배율 계산
  final audioSpeedRatio = actualRecordingSeconds > 0 ? videoDuration / actualRecordingSeconds : 1.0;

  // 기존 audioFilter에 atempo 추가
  final audioFilter = '-af "volume=2.5,atempo=${audioSpeedRatio.toStringAsFixed(3)}"';
  ```

  **참고**: `atempo` 필터는 0.5에서 2.0 사이의 값만 지원합니다. 이 범위를 벗어날 경우, 필터를 여러 번 체인처럼 연결해야 합니다. (예: `atempo=0.5,atempo=0.9`)

#### 3. **보다 효율적인 캡처 방식 탐색 (고급)**

`RepaintBoundary`를 사용하는 방식 외에 다른 방법을 고려해볼 수 있습니다.

- **네이티브 스크린 레코딩 API 활용**: Android와 iOS는 모두 화면 녹화를 위한 네이티브 API를 제공합니다. `flutter_webrtc`와 같은 라이브러리가 화면 캡처 기능을 제공하지만, 이는 보통 WebRTC 스트리밍을 위한 것이므로 파일 저장에는 추가적인 작업이 필요할 수 있습니다.
- **GPU 텍스처 직접 접근**: Flutter 엔진의 텍스처에 직접 접근하여 이미지 데이터를 가져오는 방법도 이론적으로 가능하지만, 이는 매우 복잡하고 플랫폼 종속적인 코드가 필요합니다.

### 종합적인 권장 사항

1.  **Isolate를 이용한 파일 I/O 분리**를 최우선으로 적용하여 메인 스레드의 부담을 줄이세요. 이것이 프레임 드랍을 줄이는 데 가장 효과적일 수 있습니다.
2.  캡처 로직을 최적화했음에도 프레임 손실이 발생한다면, **FFmpeg의 `atempo` 필터를 사용하여 오디오 속도를 조절**하는 후처리 방식을 도입하여 오디오-비디오 싱크를 맞추세요.
3.  `_startRecording`에서 사용하는 `Timer.periodic`의 주기를 약간 더 길게 설정하여 (예: 24fps에 해당하는 약 41ms) 시스템에 약간의 여유를 주는 것도 테스트해볼 가치가 있습니다. 이는 최대 프레임률을 약간 낮추는 대신, 프레임 드랍을 줄여 더 부드러운 결과물을 만들 수 있습니다.

이러한 단계들을 통해 프레임 손실률을 크게 줄이고, 불가피하게 발생하는 손실에 대해서도 오디오 싱크를 보정하여 최종 결과물의 품질을 향상시킬 수 있을 것입니다.
