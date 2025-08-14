import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// RankingFilterScreen is a ranking filter page.
class RankingFilterScreen extends StatefulWidget {
  /// Default Constructor
  const RankingFilterScreen({super.key});

  @override
  State<RankingFilterScreen> createState() => _RankingFilterScreenState();
}

class _RankingFilterScreenState extends State<RankingFilterScreen> {
  late CameraController controller;
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    controller = CameraController(cameras[0], ResolutionPreset.max);

    try {
      await controller.initialize();
      if (mounted) {
        setState(() {
          isInitialized = true;
        });
      }
    } catch (e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            // Handle access errors here.
            break;
          default:
            // Handle other errors here.
            break;
        }
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranking Filter'),
      ),
      body: SizedBox.expand(
        child: CameraPreview(controller),
      ),
    );
  }
}
