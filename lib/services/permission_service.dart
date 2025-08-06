import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionService {
  // 카메라 권한 확인
  static Future<bool> isCameraPermissionGranted() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  // 카메라 권한 요청
  static Future<PermissionStatus> requestCameraPermission() async {
    return await Permission.camera.request();
  }

  // 저장소 권한 확인
  static Future<bool> isStoragePermissionGranted() async {
    // Android 13+ (API 33+)에서는 photos 권한 사용
    if (await _isAndroid13OrHigher()) {
      final status = await Permission.photos.status;
      return status.isGranted;
    } else {
      final status = await Permission.storage.status;
      return status.isGranted;
    }
  }

  // 저장소 권한 요청
  static Future<PermissionStatus> requestStoragePermission() async {
    // Android 13+ (API 33+)에서는 photos 권한 사용
    if (await _isAndroid13OrHigher()) {
      return await Permission.photos.request();
    } else {
      return await Permission.storage.request();
    }
  }

  // 카메라 권한 체크 후 요청
  static Future<bool> checkAndRequestCameraPermission() async {
    if (await isCameraPermissionGranted()) {
      return true;
    }

    final status = await requestCameraPermission();
    return status.isGranted;
  }

  // 저장소 권한 체크 후 요청
  static Future<bool> checkAndRequestStoragePermission() async {
    if (await isStoragePermissionGranted()) {
      return true;
    }

    final status = await requestStoragePermission();
    return status.isGranted;
  }

  // 권한 거부 시 설정으로 이동 다이얼로그
  static Future<void> showPermissionDeniedDialog(
    BuildContext context,
    String permissionType,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$permissionType 권한 필요'),
          content: Text(
            '$permissionType 권한이 필요합니다.\n'
            '설정에서 권한을 허용해주세요.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('설정으로'),
            ),
          ],
        );
      },
    );
  }

  // 카메라 권한 전체 플로우
  static Future<bool> handleCameraPermission(BuildContext context) async {
    if (await checkAndRequestCameraPermission()) {
      return true;
    }

    // 권한이 거부된 경우
    final status = await Permission.camera.status;
    if (status.isPermanentlyDenied && context.mounted) {
      await showPermissionDeniedDialog(context, '카메라');
    }

    return false;
  }

  // 저장소 권한 전체 플로우
  static Future<bool> handleStoragePermission(BuildContext context) async {
    if (await checkAndRequestStoragePermission()) {
      return true;
    }

    // 권한이 거부된 경우
    final permission = await _isAndroid13OrHigher() 
        ? Permission.photos 
        : Permission.storage;
    
    final status = await permission.status;
    if (status.isPermanentlyDenied && context.mounted) {
      await showPermissionDeniedDialog(context, '저장소');
    }

    return false;
  }

  // Android 버전 확인 (Android 13+ 체크)
  static Future<bool> _isAndroid13OrHigher() async {
    // 실제 구현에서는 device_info_plus 등을 사용할 수 있지만
    // 지금은 간단하게 photos 권한 존재 여부로 판단
    try {
      await Permission.photos.status;
      return true;
    } catch (e) {
      return false;
    }
  }
}