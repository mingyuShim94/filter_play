import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'camera_screen.dart';
import 'settings_screen.dart';
import '../providers/permission_provider.dart';
import '../services/permission_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // 앱 시작 시 권한 상태 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(permissionProvider.notifier).checkInitialPermissions();
    });
  }

  Future<void> _startGame() async {
    // 카메라 권한 확인 및 요청
    final hasPermission = await PermissionService.handleCameraPermission(context);
    
    if (hasPermission && mounted) {
      // 권한이 있으면 카메라 화면으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CameraScreen(),
        ),
      );
    }
    // 권한이 없으면 PermissionService에서 다이얼로그가 표시됨
  }

  @override
  Widget build(BuildContext context) {
    final permissionState = ref.watch(permissionProvider);
    final cameraGranted = permissionState.cameraGranted;
    final isLoading = permissionState.isLoading;
    return Scaffold(
      appBar: AppBar(
        title: const Text('FilterPlay'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 로고 영역
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.face,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            
            // 타이틀
            Text(
              '얼굴 인식 풍선 게임',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // 설명
            Text(
              '입을 벌렸다가 닫아서 풍선을 터뜨려보세요!\n15초 안에 몇 개나 터뜨릴 수 있나요?',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            
            // 게임 시작 버튼
            ElevatedButton(
              onPressed: isLoading ? null : _startGame,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      '게임 시작',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            
            // 도움말 텍스트
            Text(
              cameraGranted 
                  ? '카메라 권한이 허용되었습니다' 
                  : '카메라 권한을 허용해주세요',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cameraGranted ? Colors.green[600] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}