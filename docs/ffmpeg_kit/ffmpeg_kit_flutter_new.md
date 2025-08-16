# FFmpeg Kit Flutter New

## 개요
- **Package**: ffmpeg_kit_flutter_new 3.2.0
- **설명**: Flutter용 FFmpegKit. Full-GPL 버전
- **발행일**: 4일 전
- **특징**: 원래 FFmpeg Kit 라이브러리의 포크 버전으로 Android V2 바인딩과 Flutter 3+와 호환

## 주요 기능

### 1. 업데이트된 바인딩
- Android 및 macOS 바인딩이 최신 Flutter 버전과 호환
- FFmpeg와 FFprobe 모두 포함

### 2. 지원 플랫폼
- Android
- iOS  
- macOS
- FFmpeg 버전: v7.1.1
- iOS 및 macOS Videotoolbox 지원

### 3. 지원 아키텍처

**Android**:
- arm-v7a, arm-v7a-neon, arm64-v8a, x86, x86_64
- Android API Level 24 이상 필요
- Kotlin 1.8.22 이상 필요

**iOS**:
- armv7, armv7s, arm64, arm64-simulator, i386, x86_64, x86_64-mac-catalyst, arm64-mac-catalyst
- iOS SDK 14.0 이상 필요

**macOS**:
- arm64, x86_64
- macOS SDK 10.15 이상 필요

### 4. 외부 라이브러리 지원
- **25개 외부 라이브러리**: dav1d, fontconfig, freetype, fribidi, gmp, gnutls, kvazaar, lame, libass, libiconv, libilbc, libtheora, libvorbis, libvpx, libwebp, libxml2, opencore-amr, opus, shine, snappy, soxr, speex, twolame, vo-amrwbenc, zimg
- **GPL 라이센스 라이브러리 4개**: vid.stab, x264, x265, xvidcore

## 설치

```yaml
dependencies:  
  ffmpeg_kit_flutter_new: ^3.2.0
```

## 패키지 종류

| 패키지명 | 설명 |
|---------|------|
| Minimal | FFmpeg Kit 최소 버전 |
| Minimal-GPL | GPL 라이센스 최소 버전 |
| HTTPS | HTTPS 지원 FFmpeg Kit |
| HTTPS-GPL | GPL 라이센스 HTTPS 버전 |
| Audio | 오디오 처리 중심 FFmpeg Kit |
| Video | 비디오 처리 중심 FFmpeg Kit |
| Full | FFmpeg Kit 전체 버전 |
| Full-GPL | GPL 라이센스 전체 버전 |

## 플랫폼 요구사항

| Android API Level | Kotlin 최소 버전 | iOS 최소 배포 타겟 | macOS 최소 배포 타겟 |
|-------------------|------------------|-------------------|-------------------|
| 24 | 1.8.22 | 14 | 10.15 |

## 사용법

### 기본 FFmpeg 명령 실행
```dart
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';

FFmpegKit.execute('-i file1.mp4 -c:v mpeg4 file2.mp4').then((session) async {
    final returnCode = await session.getReturnCode();  
    if (ReturnCode.isSuccess(returnCode)) {  
        // 성공  
    } else if (ReturnCode.isCancel(returnCode)) {  
        // 취소  
    } else {
        // 오류  
    }
});
```

### 커스텀 로그 콜백과 함께 실행
```dart
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
final outputPath = 'file2.mp4';

FFmpegKit.execute('-i file1.mp4 -c:v mpeg4 file2.mp4').thenReturnResultOrLogs(
    (_) => outputPath,
).then((result) => print('FFmpeg 명령 성공: $result'))
  .catchError((error) => print('FFmpeg 명령 실패: $error'));
```

### 세션 정보 접근
```dart
FFmpegKit.execute('-i file1.mp4 -c:v mpeg4 file2.mp4').then((session) async {  
    final sessionId = session.getSessionId();  
    final command = session.getCommand();  
    final commandArguments = session.getArguments();  
    final state = await session.getState();  
    final returnCode = await session.getReturnCode();  
    final startTime = session.getStartTime();
    final endTime = await session.getEndTime();
    final duration = await session.getDuration();  
    final output = await session.getOutput();  
    final failStackTrace = await session.getFailStackTrace();  
    final logs = await session.getLogs();  
    final statistics = await (session as FFmpegSession).getStatistics();  
});
```

### 비동기 실행 (콜백 포함)
```dart
FFmpegKit.executeAsync('-i file1.mp4 -c:v mpeg4 file2.mp4', (Session session) async {
    // 세션 실행 시 호출  
}, (Log log) {  
    // 세션이 로그를 출력할 때 호출  
}, (Statistics statistics) {  
    // 세션이 통계를 생성할 때 호출  
});
```

### FFprobe 명령 실행
```dart
FFprobeKit.execute(ffprobeCommand).then((session) async {  
    // 세션 실행 시 호출  
});  
```

### 미디어 정보 가져오기
```dart
FFprobeKit.getMediaInformation('<파일 경로 또는 URL>').then((session) async {  
    final information = await session.getMediaInformation();  
    if (information == null) {  
        final state = FFmpegKitConfig.sessionStateToString(await session.getState());
        final returnCode = await session.getReturnCode();
        final failStackTrace = await session.getFailStackTrace();
        final duration = await session.getDuration();
        final output = await session.getOutput();
    }
});
```

### 진행중인 FFmpeg 작업 중지
```dart
// 모든 세션 중지
FFmpegKit.cancel();

// 특정 세션 중지
FFmpegKit.cancel(sessionId);  
```

### Android SAF URI 변환
```dart
// 파일 읽기
FFmpegKitConfig.selectDocumentForRead('*/*').then((uri) {  
    FFmpegKitConfig.getSafParameterForRead(uri!).then((safUrl) {
        FFmpegKit.executeAsync("-i ${safUrl!} -c:v mpeg4 file2.mp4");
    });
});

// 파일 쓰기
FFmpegKitConfig.selectDocumentForWrite('video.mp4', 'video/*').then((uri) {
    FFmpegKitConfig.getSafParameterForWrite(uri!).then((safUrl) {
        FFmpegKit.executeAsync("-i file1.mp4 -c:v mpeg4 ${safUrl}");
    });
});  
```

### 세션 히스토리 가져오기
```dart
FFmpegKit.listSessions().then((sessionList) {  
    sessionList.forEach((session) {
        final sessionId = session.getSessionId();
    });
});  

FFprobeKit.listFFprobeSessions().then((sessionList) {
    sessionList.forEach((session) {
        final sessionId = session.getSessionId();
    });
});  

FFprobeKit.listMediaInformationSessions().then((sessionList) {
    sessionList.forEach((session) {
        final sessionId = session.getSessionId();
    });
});
```

### 글로벌 콜백 활성화
```dart
// 세션 완료 콜백
FFmpegKitConfig.enableFFmpegSessionCompleteCallback((session) {
    final sessionId = session.getSessionId();
});  

FFmpegKitConfig.enableFFprobeSessionCompleteCallback((session) {
    final sessionId = session.getSessionId();
});  

FFmpegKitConfig.enableMediaInformationSessionCompleteCallback((session) {
    final sessionId = session.getSessionId();
});  

// 로그 콜백
FFmpegKitConfig.enableLogCallback((log) {  
    final message = log.getMessage();
});

// 통계 콜백
FFmpegKitConfig.enableStatisticsCallback((statistics) {  
    final size = statistics.getSize();
});  
```

### 폰트 디렉토리 등록
```dart
FFmpegKitConfig.setFontDirectoryList(["/system/fonts", "/System/Library/Fonts", "<폰트가 있는 폴더>"]);
```

## 라이센스
- 기본적으로 LGPL 3.0 라이센스
- 일부 패키지는 GPL v3.0 라이센스로 효력 발생