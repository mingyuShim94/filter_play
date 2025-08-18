import 'package:flutter/material.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:permission_handler/permission_handler.dart';

class ScreenRecordingExample extends StatefulWidget {
  @override
  _ScreenRecordingExampleState createState() => _ScreenRecordingExampleState();
}

class _ScreenRecordingExampleState extends State<ScreenRecordingExample> {
  bool _isRecording = false;
  String? _videoPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('네이티브 화면 녹화')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_isRecording ? '녹화 중...' : '녹화 준비됨'),
          SizedBox(height: 20),
          
          // CameraPreview 등 현재 UI 유지
          Container(
            height: 400,
            color: Colors.grey[300],
            child: Center(
              child: Text('여기에 CameraPreview + 오버레이'),
            ),
          ),
          
          SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _isRecording ? null : _startRecording,
                child: Text('녹화 시작'),
              ),
              ElevatedButton(
                onPressed: _isRecording ? _stopRecording : null,
                child: Text('녹화 중지'),
              ),
            ],
          ),
          
          if (_videoPath != null) ...[
            SizedBox(height: 20),
            Text('저장됨: ${_videoPath!.split('/').last}'),
          ],
        ],
      ),
    );
  }

  Future<void> _startRecording() async {
    // 권한 확인
    if (!await _checkPermissions()) return;

    try {
      bool started = await FlutterScreenRecording.startRecordScreenAndAudio(
        "ranking_filter_${DateTime.now().millisecondsSinceEpoch}",
        titleNotification: "FilterPlay 녹화 중",
        messageNotification: "화면과 오디오를 녹화하고 있습니다"
      );

      if (started) {
        setState(() {
          _isRecording = true;
          _videoPath = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('녹화 시작 실패: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      String path = await FlutterScreenRecording.stopRecordScreen;
      
      setState(() {
        _isRecording = false;
        _videoPath = path;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('동영상이 저장되었습니다')),
      );

      // ResultScreen으로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            score: 0,
            totalBalloons: 0,
            videoPath: path,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('녹화 중지 실패: $e')),
      );
    }
  }

  Future<bool> _checkPermissions() async {
    // Android 권한
    Map<Permission, PermissionStatus> permissions = await [
      Permission.microphone,
      Permission.storage,
    ].request();

    return permissions.values.every((status) => status == PermissionStatus.granted);
  }
}