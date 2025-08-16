import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

class ResultScreen extends ConsumerWidget {
  final int score;
  final int totalBalloons;
  final String? videoPath; // 동영상 경로 추가

  const ResultScreen({
    super.key,
    required this.score,
    required this.totalBalloons,
    this.videoPath, // 선택적 매개변수
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 0으로 나누기 방지
    final percentage =
        totalBalloons > 0 ? (score / totalBalloons * 100).round() : 0;
    final isExcellent = percentage >= 80;
    final isGood = percentage >= 60;

    // 동영상 전용 모드인지 확인
    final isVideoOnlyMode = videoPath != null && totalBalloons == 0;

    return Scaffold(
      backgroundColor: isVideoOnlyMode
          ? Colors.black
          : (isExcellent ? Colors.amber[50] : Colors.blue[50]),
      appBar: AppBar(
        title: Text(isVideoOnlyMode ? '녹화 영상' : '게임 결과'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isVideoOnlyMode ? Colors.white : null,
        iconTheme:
            isVideoOnlyMode ? const IconThemeData(color: Colors.white) : null,
      ),
      body: isVideoOnlyMode
          ?
          // 동영상 전용 모드 - 오버플로우 방지, 여백 제거
          VideoPreviewWidget(
              videoPath: videoPath!,
              isVideoOnlyMode: true,
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

  const VideoPreviewWidget({
    super.key,
    required this.videoPath,
    this.isVideoOnlyMode = false,
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
      print('동영상 초기화 오류: $e');
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

  @override
  Widget build(BuildContext context) {
    if (widget.isVideoOnlyMode) {
      // 동영상 전용 모드일 때는 전체 화면 차지, 여백 없음
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: _isInitialized
            ? Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: _buildVideoPreview(),
                ),
              )
            : _buildVideoPreview(), // 로딩 중이거나 오류일 때도 전체 화면
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 32,
              color: Colors.red,
            ),
            const SizedBox(height: 8),
            const Text(
              '동영상 로드 실패',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$_errorMessage',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
      print('동영상 초기화 오류: $e');
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
