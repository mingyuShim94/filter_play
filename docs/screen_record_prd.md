네, 알겠습니다. 지금까지 논의된 내용을 바탕으로, Flutter 앱에서 **iOS와 Android를 모두 지원하며 앱 화면만(소리 포함) 녹화**하는 기능의 구체적인 구현 계획을 단계별로 정리해 드리겠습니다.

이 계획은 여러 패키지를 조합하는 복잡한 과정이지만, 현재 Flutter 생태계에서 요구사항을 만족시키는 가장 확실한 방법입니다.

### 최종 목표

`RepaintBoundary`로 지정된 특정 위젯 영역을 녹화하고, 마이크로 녹음된 소리를 합쳐 하나의 MP4 동영상 파일로 저장한다.

### 필요한 패키지 요약

- **핵심 로직:**
  - `flutter/rendering.dart`: 위젯을 이미지로 캡처하기 위한 Flutter 기본 라이브러리.
  - `record`: 크로스플랫폼 오디오 녹음을 위한 패키지.
  - `ffmpeg_kit_flutter`: 캡처된 이미지와 오디오를 동영상으로 합성(인코딩)하기 위한 패키지.
- **보조 도구:**
  - `path_provider`: 파일 저장을 위한 임시/영구 경로를 얻기 위한 패키지.
  - `permission_handler`: 마이크, 저장소 등 필요한 권한을 요청하기 위한 패키지.

---

## 구현 계획 (Step-by-Step)

### 1단계: 프로젝트 설정 및 권한 구성

1.  **`pubspec.yaml`에 의존성 추가:**

    ```yaml
    dependencies:
      flutter:
        sdk: flutter

      # 기능 구현 패키지
      record: ^5.0.0 # 오디오 녹음
      ffmpeg_kit_flutter: ^5.1.0 # 동영상/오디오 합성

      # 유틸리티 패키지
      path_provider: ^2.0.15
      permission_handler: ^10.2.0
    ```

    터미널에서 `flutter pub get` 실행하여 패키지를 설치합니다.

2.  **플랫폼별 권한 설정:**
    - **iOS (`ios/Runner/Info.plist`):**
      ```xml
      <key>NSMicrophoneUsageDescription</key>
      <string>화면 녹화 시 오디오를 함께 녹음하기 위해 마이크 권한이 필요합니다.</string>
      <key>NSPhotoLibraryAddUsageDescription</key>
      <string>녹화된 동영상을 갤러리에 저장하기 위해 권한이 필요합니다.</string>
      ```
    - **Android (`android/app/src/main/AndroidManifest.xml`):**
      ```xml
      <uses-permission android:name="android.permission.RECORD_AUDIO" />
      <!-- Android 10 (API 29) 미만 버전을 지원할 경우 저장소 쓰기 권한 추가 -->
      <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
      ```

### 2단계: UI 구성 및 상태 관리

1.  **`GlobalKey` 생성:**
    캡처할 `RepaintBoundary`를 식별하기 위한 `GlobalKey`를 state 변수로 선언합니다.

    ```dart
    final GlobalKey _captureKey = GlobalKey();
    ```

2.  **UI 레이아웃:**
    녹화할 위젯(예: `Scaffold`, `Container` 등)을 `RepaintBoundary`로 감싸고, 위에서 생성한 `_captureKey`를 할당합니다.

    ```dart
    RepaintBoundary(
      key: _captureKey,
      child: YourWidgetToRecord(), // 녹화할 위젯
    )
    ```

3.  **상태 변수 및 컨트롤러 선언:**
    녹화 상태, 프레임 캡처 타이머, 오디오 레코더 인스턴스를 관리할 변수를 선언합니다.

    ```dart
    bool _isRecording = false;
    Timer? _frameCaptureTimer;
    final AudioRecorder _audioRecorder = AudioRecorder();
    ```

4.  **버튼 추가:**
    녹화 시작/중지 기능을 수행할 버튼을 UI에 배치합니다.

### 3단계: 녹화 시작 로직 (`startRecording`)

1.  **권한 확인 및 요청:**
    `permission_handler`를 사용해 `Permission.microphone`과 `Permission.storage` 권한을 요청합니다. 권한이 거부되면 녹화를 시작하지 않습니다.

2.  **임시 저장 경로 생성:**
    `path_provider`의 `getTemporaryDirectory()`를 사용하여 녹화 세션을 위한 고유한 임시 폴더를 생성합니다. 이 폴더 안에 이미지 프레임과 오디오 파일을 저장합니다.

    ```dart
    final tempDir = await getTemporaryDirectory();
    final sessionDir = Directory('${tempDir.path}/record_${DateTime.now().millisecondsSinceEpoch}');
    await sessionDir.create();
    ```

3.  **오디오 녹음 시작:**
    `record` 패키지를 사용하여 오디오 녹음을 시작하고, 위에서 만든 세션 폴더 내에 `audio.m4a`와 같은 이름으로 저장합니다.

    ```dart
    await _audioRecorder.start(const RecordConfig(), path: '${sessionDir.path}/audio.m4a');
    ```

4.  **프레임 캡처 시작:**
    `Timer.periodic`을 사용하여 주기적으로(`Duration(milliseconds: 1000 ~/ 24)` -> 약 24fps) 다음 작업을 수행합니다.
    - `_captureKey`를 이용해 `RepaintBoundary`를 `ui.Image`로 변환하고, 다시 `Uint8List` (PNG 데이터)로 변환합니다.
    - 변환된 이미지 데이터를 세션 폴더 내에 순차적인 파일 이름(예: `frame_00001.png`, `frame_00002.png`...)으로 저장합니다. **파일 이름의 숫자 패딩은 FFmpeg에서 매우 중요합니다.**
    - 상태를 `_isRecording = true`로 변경하여 UI를 업데이트합니다.

### 4단계: 녹화 중지 및 동영상 합성 (`stopRecording`)

1.  **타이머 및 녹음 중지:**
    `_frameCaptureTimer`를 취소하고, `_audioRecorder.stop()`을 호출하여 오디오 녹음을 종료합니다.

2.  **처리 중 UI 표시:**
    상태를 `_isRecording = false`로 변경하고, "동영상 처리 중..."과 같은 로딩 인디케이터를 사용자에게 보여줍니다. (FFmpeg 합성은 시간이 걸릴 수 있습니다)

3.  **FFmpeg 명령어 실행:**
    `ffmpeg_kit_flutter`를 사용하여 저장된 이미지 시퀀스와 오디오 파일을 하나의 MP4 파일로 합성합니다.

    - **입력:** 이미지 시퀀스 경로, 오디오 파일 경로
    - **출력:** 최종 비디오 파일 경로 (예: `Documents` 폴더)
    - **FFmpeg 명령어 예시:**

      ```dart
      // frame_path: '.../frame_%05d.png'
      // audio_path: '.../audio.m4a'
      // output_path: '.../final_video.mp4'

      final command = "-framerate 24 -i \"$frame_path\" -i \"$audio_path\" -c:v libx264 -c:a aac -pix_fmt yuv420p -shortest \"$output_path\"";

      await FFmpegKit.execute(command);
      ```

    - `-pix_fmt yuv420p`: iOS를 포함한 대부분의 플레이어와의 호환성을 위해 필수적인 옵션입니다.

4.  **임시 파일 정리:**
    동영상 합성이 성공적으로 완료되면, 이미지 프레임과 오디오 파일이 저장되었던 임시 세션 폴더 전체를 삭제하여 기기 저장 공간을 낭비하지 않도록 합니다.

5.  **완료 알림:**
    사용자에게 녹화가 완료되었고 동영상이 저장되었음을 `SnackBar`나 다이얼로그로 알립니다. (선택적으로 `gallery_saver` 패키지를 사용해 갤러리에 저장할 수 있습니다.)

이 계획을 따르면, 여러 기술을 체계적으로 조합하여 원하시는 기능을 안정적으로 구현할 수 있을 것입니다.
