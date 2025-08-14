import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';

class RecordingResultScreen extends StatefulWidget {
  final String videoPath;
  final int frameCount;
  final Duration recordingDuration;
  final bool hasAudio;

  const RecordingResultScreen({
    super.key,
    required this.videoPath,
    required this.frameCount,
    required this.recordingDuration,
    required this.hasAudio,
  });

  @override
  State<RecordingResultScreen> createState() => _RecordingResultScreenState();
}

class _RecordingResultScreenState extends State<RecordingResultScreen> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isPlaying = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final file = File(widget.videoPath);
      if (!await file.exists()) {
        throw Exception('비디오 파일을 찾을 수 없습니다');
      }

      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();

      // 비디오 재생 완료 시 콜백 설정
      _controller!.addListener(() {
        if (_controller!.value.position >= _controller!.value.duration) {
          setState(() {
            _isPlaying = false;
          });
        }
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _togglePlayPause() async {
    if (_controller == null) return;

    try {
      if (_isPlaying) {
        await _controller!.pause();
        setState(() {
          _isPlaying = false;
        });
      } else {
        // 재생이 끝났으면 처음부터 재생
        if (_controller!.value.position >= _controller!.value.duration) {
          await _controller!.seekTo(Duration.zero);
        }
        await _controller!.play();
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = '재생 중 오류가 발생했습니다: $e';
      });
    }
  }

  Future<void> _saveToGallery() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // 갤러리에 저장하는 로직
      // 실제 구현에서는 gal 패키지나 image_gallery_saver 패키지 사용
      final file = File(widget.videoPath);
      final documentsDir = await getApplicationDocumentsDirectory();
      final savedPath = '${documentsDir.path}/saved_videos';
      final savedDir = Directory(savedPath);
      
      if (!await savedDir.exists()) {
        await savedDir.create(recursive: true);
      }
      
      final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final newPath = '$savedPath/$fileName';
      await file.copy(newPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('비디오가 저장되었습니다: $fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: '확인',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _retryRecording() {
    Navigator.of(context).pop(true); // true를 반환하여 다시 녹화 신호
  }

  void _goBack() {
    Navigator.of(context).pop(false); // false를 반환하여 일반 종료
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  Widget _buildVideoInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '녹화 정보',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('녹화 시간', _formatDuration(widget.recordingDuration)),
          _buildInfoRow('프레임 수', '${widget.frameCount}개'),
          _buildInfoRow('오디오', widget.hasAudio ? '포함' : '없음'),
          if (_controller != null && _controller!.value.isInitialized) ...[
            _buildInfoRow('해상도', 
              '${_controller!.value.size.width.toInt()}x${_controller!.value.size.height.toInt()}'),
            _buildInfoRow('비디오 길이', _formatDuration(_controller!.value.duration)),
          ],
          FutureBuilder<int>(
            future: File(widget.videoPath).length(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return _buildInfoRow('파일 크기', _formatFileSize(snapshot.data!));
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('녹화 결과'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _goBack,
        ),
      ),
      body: Column(
        children: [
          // 비디오 플레이어 영역
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: _buildVideoPlayer(),
            ),
          ),
          
          // 컨트롤 영역
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 재생 컨트롤
                  _buildPlayControls(),
                  
                  const SizedBox(height: 16),
                  
                  // 비디오 정보
                  Expanded(child: _buildVideoInfo()),
                  
                  const SizedBox(height: 16),
                  
                  // 액션 버튼들
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              '비디오를 로딩 중...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              '비디오 로딩 실패',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '알 수 없는 오류',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeVideo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: Text(
          '비디오를 준비 중...',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
        
        // 재생/일시정지 오버레이
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayControls() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // 재생 바
        VideoProgressIndicator(
          _controller!,
          allowScrubbing: true,
          colors: const VideoProgressColors(
            playedColor: Colors.red,
            bufferedColor: Colors.grey,
            backgroundColor: Colors.black,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // 재생 시간 표시
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ValueListenableBuilder(
              valueListenable: _controller!,
              builder: (context, value, child) {
                return Text(
                  _formatDuration(value.position),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
            Text(
              _formatDuration(_controller!.value.duration),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // 다시 녹화 버튼
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _retryRecording,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 녹화'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // 저장 버튼
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveToGallery,
            icon: _isSaving 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.download),
            label: Text(_isSaving ? '저장 중...' : '저장'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}