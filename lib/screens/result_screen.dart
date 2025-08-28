import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../services/video_processing_service.dart';

class ResultScreen extends ConsumerWidget {
  final int score;
  final int totalBalloons;
  final String? videoPath; // 동영상 경로 추가
  final bool isOriginalVideo; // 원본 영상인지 크롭된 영상인지
  final VideoProcessingError? processingError; // 비디오 처리 에러 정보

  const ResultScreen({
    super.key,
    required this.score,
    required this.totalBalloons,
    this.videoPath, // 선택적 매개변수
    this.isOriginalVideo = true, // 기본값은 원본 영상
    this.processingError, // 에러 정보 (선택적)
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 에러 모드 확인
    final isErrorMode = processingError != null;
    
    // 0으로 나누기 방지
    final percentage =
        totalBalloons > 0 ? (score / totalBalloons * 100).round() : 0;
    final isExcellent = percentage >= 80;
    final isGood = percentage >= 60;

    // 동영상 전용 모드인지 확인
    final isVideoOnlyMode = videoPath != null && totalBalloons == 0 && !isErrorMode;

    return Scaffold(
      backgroundColor: isErrorMode
          ? Colors.red[50]
          : isVideoOnlyMode
          ? Colors.black
          : (isExcellent ? Colors.amber[50] : Colors.blue[50]),
      appBar: AppBar(
        title: Text(isErrorMode 
            ? '비디오 처리 오류' 
            : isVideoOnlyMode 
            ? '녹화 영상' 
            : '게임 결과'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isVideoOnlyMode ? Colors.white : null,
        iconTheme:
            isVideoOnlyMode ? const IconThemeData(color: Colors.white) : null,
      ),
      body: isErrorMode
          ? 
          // 에러 정보 표시 모드
          ErrorInfoWidget(error: processingError!)
          : isVideoOnlyMode
          ?
          // 동영상 전용 모드 - 오버플로우 방지, 여백 제거
          VideoPreviewWidget(
              videoPath: videoPath!,
              isVideoOnlyMode: true,
              processingError: processingError, // FFmpeg 에러 정보 전달
            )
          :
          // 일반 게임 결과 모드
          SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 게임 결과 모드

                  Text(
                    isExcellent
                        ? '🎉'
                        : isGood
                            ? '😊'
                            : '😔',
                    style: const TextStyle(fontSize: 80),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    isExcellent
                        ? '완벽해요!'
                        : isGood
                            ? '잘했어요!'
                            : '다시 도전해보세요!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isExcellent
                              ? Colors.amber[700]
                              : Colors.blue[700],
                        ),
                  ),
                  const SizedBox(height: 32),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          '터뜨린 풍선',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$score',
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                            ),
                            Text(
                              ' / $totalBalloons',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$percentage% 성공!',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // 녹화 영상 미리보기
                  if (videoPath != null)
                    VideoPreviewWidget(
                      videoPath: videoPath!,
                      isVideoOnlyMode: false,
                      processingError: processingError, // FFmpeg 에러 정보 전달
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          '📹 녹화된 영상이 없습니다',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                  // 액션 버튼들
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.popUntil(
                                context, (route) => route.isFirst);
                          },
                          child: const Text('홈으로'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('다시하기'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

// 동영상 미리보기 위젯
class VideoPreviewWidget extends StatefulWidget {
  final String videoPath;
  final bool isVideoOnlyMode;
  final VideoProcessingError? processingError; // FFmpeg 처리 에러 정보

  const VideoPreviewWidget({
    super.key,
    required this.videoPath,
    this.isVideoOnlyMode = false,
    this.processingError, // 선택적 매개변수
  });

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.file(File(widget.videoPath));
      await _controller.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      // VideoPreviewWidget 동영상 초기화 오류 처리 (로깅 생략)
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _showFullScreenVideo() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            VideoFullScreenWidget(videoPath: widget.videoPath),
      ),
    );
  }

  void _copyErrorToClipboard() async {
    // FFmpeg 처리 에러 정보 포함
    final ffmpegErrorInfo = widget.processingError != null 
        ? '''

FFmpeg 비디오 처리 에러 정보:
==============================
${widget.processingError!.toDetailedString()}
''' 
        : '';

    final errorInfo = '''
동영상 로드 에러 정보
===================

에러 메시지: $_errorMessage
파일 경로: ${widget.videoPath}
타임스탬프: ${DateTime.now().toString()}

디버깅 정보:
- 파일 존재 여부: ${File(widget.videoPath).existsSync()}
- 파일 크기: ${await _getFileSize()}

해결 방법:
1. 파일 경로가 올바른지 확인
2. 파일이 손상되지 않았는지 확인  
3. 지원되는 비디오 포맷인지 확인
4. 저장소 권한이 있는지 확인$ffmpegErrorInfo
''';

    await Clipboard.setData(ClipboardData(text: errorInfo));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('에러 정보가 클립보드에 복사되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _retryVideoLoad() {
    setState(() {
      _hasError = false;
      _isInitialized = false;
      _errorMessage = null;
    });
    _initializeVideo();
  }

  Future<String> _getFileSize() async {
    try {
      final file = File(widget.videoPath);
      if (await file.exists()) {
        final size = await file.length();
        return '${(size / 1024 / 1024).toStringAsFixed(2)} MB';
      } else {
        return '파일이 존재하지 않음';
      }
    } catch (e) {
      return '크기 확인 실패: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isVideoOnlyMode) {
      // 동영상 전용 모드일 때 화면에 맞게 크기 조정
      return SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(16.0), // 여백 추가
          child: _isInitialized
              ? Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width - 32,
                      maxHeight: MediaQuery.of(context).size.height * 0.8, // 화면 높이의 80%로 제한
                    ),
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: _buildVideoPreview(),
                    ),
                  ),
                )
              : _buildVideoPreview(), // 로딩 중이거나 오류일 때
        ),
      );
    } else {
      // 일반 모드일 때는 고정 높이
      return Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: _buildVideoPreview(),
        ),
      );
    }
  }

  Widget _buildVideoPreview() {
    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              const Text(
                '동영상 로드 실패',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '에러 상세 정보:',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_errorMessage',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '파일 경로:',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.videoPath,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.left,
                    ),
                    // FFmpeg 처리 에러 정보 추가 표시
                    if (widget.processingError != null) ...[
                      const SizedBox(height: 12),
                      const Divider(color: Colors.red, thickness: 1),
                      const SizedBox(height: 8),
                      const Text(
                        'FFmpeg 비디오 처리 에러:',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: SingleChildScrollView(
                          child: Text(
                            widget.processingError!.message,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (widget.processingError!.returnCode != null)
                        Text(
                          'FFmpeg 리턴 코드: ${widget.processingError!.returnCode} (${widget.processingError!.returnCodeMeaning ?? "알 수 없음"})',
                          style: const TextStyle(
                            color: Colors.yellow,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (widget.processingError!.logs.isNotEmpty) ...[
                        const Text(
                          '최근 FFmpeg 로그:',
                          style: TextStyle(
                            color: Colors.cyan,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 80),
                          child: SingleChildScrollView(
                            child: Text(
                              widget.processingError!.logs.take(5).join('\n'),
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 9,
                                fontFamily: 'monospace',
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _copyErrorToClipboard,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('에러 복사'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _retryVideoLoad,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('다시 시도'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
            SizedBox(height: 8),
            Text(
              '동영상 로딩 중...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // 동영상 플레이어
        Center(
          child: AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
        ),

        // 컨트롤 오버레이
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.3),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 재생/일시정지 버튼
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 전체화면 버튼
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: _showFullScreenVideo,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.fullscreen,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// 전체화면 동영상 플레이어
class VideoFullScreenWidget extends StatefulWidget {
  final String videoPath;

  const VideoFullScreenWidget({
    super.key,
    required this.videoPath,
  });

  @override
  State<VideoFullScreenWidget> createState() => _VideoFullScreenWidgetState();
}

class _VideoFullScreenWidgetState extends State<VideoFullScreenWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.file(File(widget.videoPath));
      await _controller.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play(); // 전체화면에서는 자동 재생
      }
    } catch (e) {
      // 전체화면 동영상 초기화 오류 처리 (로깅 생략)
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('녹화된 영상'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _buildFullScreenVideo(),
      ),
    );
  }

  Widget _buildFullScreenVideo() {
    if (_hasError) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            '동영상을 로드할 수 없습니다',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? '알 수 없는 오류',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (!_isInitialized) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Colors.white,
          ),
          SizedBox(height: 16),
          Text(
            '동영상 로딩 중...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 동영상 플레이어
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),

        const SizedBox(height: 20),

        // 컨트롤
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _togglePlayPause,
              icon: Icon(
                _controller.value.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                size: 48,
                color: Colors.white,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // 진행 상태 바
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: VideoProgressIndicator(
            _controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Colors.white,
              bufferedColor: Colors.grey,
              backgroundColor: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}

// 에러 정보 표시 위젯
class ErrorInfoWidget extends StatelessWidget {
  final VideoProcessingError error;

  const ErrorInfoWidget({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 에러 헤더
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[300]!),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '비디오 처리 실패',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.red[800],
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        error.message,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          // 에러 상세 정보
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더와 복사 버튼
                  Row(
                    children: [
                      Text(
                        '상세 에러 정보',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _copyErrorToClipboard(context),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('복사'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 에러 정보 스크롤뷰
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          error.toDetailedString(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 액션 버튼들
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: const Text('홈으로'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('다시 시도'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copyErrorToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: error.toDetailedString()));
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('에러 정보가 클립보드에 복사되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
