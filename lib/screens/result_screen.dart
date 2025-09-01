import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../services/video_processing_service.dart';
import '../services/gallery_service.dart';

class ResultScreen extends ConsumerWidget {
  final String? videoPath;
  final bool isOriginalVideo;
  final VideoProcessingError? processingError;
  final String? originalVideoPath;

  const ResultScreen({
    super.key,
    this.videoPath,
    this.isOriginalVideo = true,
    this.processingError,
    this.originalVideoPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isErrorMode = processingError != null;
    final isVideoOnlyMode = videoPath != null && !isErrorMode;

    return Scaffold(
      backgroundColor: isErrorMode
          ? Colors.red[50]
          : isVideoOnlyMode
              ? Colors.black
              : Colors.blue[50],
      appBar: AppBar(
        title: Text(isErrorMode
            ? 'Video Processing Error'
            : isVideoOnlyMode
                ? 'Recorded Video'
                : 'Results'),
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
              Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        color: Colors.black,
                        child: VideoPreviewWidget(
                          videoPath: videoPath!,
                          isVideoOnlyMode: true,
                          processingError: processingError, // FFmpeg 에러 정보 전달
                        ),
                      ),
                    ),
                    // Gallery save buttons for video-only mode
                    if (videoPath != null)
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: _GallerySaveButtons(
                            croppedVideoPath: videoPath,
                          ),
                        ),
                      ),
                  ],
                )
              :
              // 기본 결과 화면
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            '📹 No recorded video available',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.popUntil(
                                    context, (route) => route.isFirst);
                              },
                              child: const Text('Home'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('Try Again'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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

  void _copyErrorToClipboard() async {
    // FFmpeg 처리 에러 정보 포함
    final ffmpegErrorInfo = widget.processingError != null
        ? '''

FFmpeg Video Processing Error Information:
======================================
${widget.processingError!.toDetailedString()}
'''
        : '';

    final errorInfo = '''
Video Load Error Information
==========================

Error Message: $_errorMessage
File Path: ${widget.videoPath}
Timestamp: ${DateTime.now().toString()}

Debugging Information:
- File exists: ${File(widget.videoPath).existsSync()}
- File size: ${await _getFileSize()}

Solution:
1. Check if file path is correct
2. Check if file is not corrupted
3. Check if video format is supported
4. Check if storage permission is granted$ffmpegErrorInfo
''';

    await Clipboard.setData(ClipboardData(text: errorInfo));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error information copied to clipboard'),
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
        return 'File does not exist';
      }
    } catch (e) {
      return 'Size check failed: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isVideoOnlyMode) {
      // 동영상 전용 모드일 때 화면에 맞게 크기 조정

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
            : _buildVideoPreview(), // 로딩 중이거나 오류일 때
      );
    } else {
      // 일반 모드일 때는 고정 높이 (20% 감소: 200 -> 160)
      return Container(
        width: double.infinity,
        height: 160,
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
                'Video Load Failed',
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
                      'Error Details:',
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
                      'File Path:',
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
                        'FFmpeg Video Processing Error:',
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
                          'FFmpeg Return Code: ${widget.processingError!.returnCode} (${widget.processingError!.returnCodeMeaning ?? "Unknown"})',
                          style: const TextStyle(
                            color: Colors.yellow,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (widget.processingError!.logs.isNotEmpty) ...[
                        const Text(
                          'Recent FFmpeg Logs:',
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
                    label: const Text('Copy Error'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _retryVideoLoad,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
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
              strokeWidth: 3,
            ),
            SizedBox(height: 16),
            Text(
              '🎬 Loading video...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please wait',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
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
                        'Video Processing Failed',
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
                        'Detailed Error Information',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _copyErrorToClipboard(context),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy'),
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
                  child: const Text('Home'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Retry'),
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
          content: Text('Error information copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

// 갤러리 저장 버튼 위젯
class _GallerySaveButtons extends StatefulWidget {
  final String? croppedVideoPath;

  const _GallerySaveButtons({
    this.croppedVideoPath,
  });

  @override
  State<_GallerySaveButtons> createState() => _GallerySaveButtonsState();
}

class _GallerySaveButtonsState extends State<_GallerySaveButtons> {
  bool _isCroppedSaving = false;
  double _croppedProgress = 0.0;
  String _croppedStatus = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),

        // 저장 버튼
        if (widget.croppedVideoPath != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  _isCroppedSaving ? null : () => _saveCroppedToGallery(),
              icon: Icon(
                _isCroppedSaving ? Icons.hourglass_empty : Icons.save_alt,
                size: 25,
              ),
              label: Text(
                _isCroppedSaving ? 'Saving...' : 'Save',
                style: const TextStyle(fontSize: 17),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                backgroundColor: Colors.purple[600],
                foregroundColor: Colors.white,
              ),
            ),
          ),
        if (_isCroppedSaving) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 4,
            child: LinearProgressIndicator(
              value: _croppedProgress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[600]!),
            ),
          ),
          if (_croppedStatus.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _croppedStatus,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ],
    );
  }

  // 크롭된 영상을 갤러리에 저장
  Future<void> _saveCroppedToGallery() async {
    if (widget.croppedVideoPath == null || _isCroppedSaving) return;

    setState(() {
      _isCroppedSaving = true;
      _croppedProgress = 0.0;
      _croppedStatus = 'Preparing to save...';
    });

    try {
      final result = await GalleryService.saveVideoToGallery(
        filePath: widget.croppedVideoPath!,
        albumName: 'FilterPlay',
        progressCallback: (progress, status) {
          if (mounted) {
            setState(() {
              _croppedProgress = progress;
              _croppedStatus = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isCroppedSaving = false;
          _croppedProgress = 0.0;
          _croppedStatus = '';
        });

        if (result.success) {
          // 성공 스낵바 및 갤러리 열기 옵션
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Camera video saved to gallery! ✅'),
              action: SnackBarAction(
                label: 'Open Gallery',
                onPressed: () => GalleryService.openGallery(),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          // 실패 스낵바
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Save failed: ${result.message}'),
              backgroundColor: Colors.red[600],
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCroppedSaving = false;
          _croppedProgress = 0.0;
          _croppedStatus = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error occurred while saving: $e'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
