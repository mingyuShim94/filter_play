import 'dart:io';
import 'package:flutter/foundation.dart';

class AdConfig {
  // 전면 광고 ID (플랫폼별)
  static String get interstitialAdUnitId {
    if (kDebugMode) {
      // 테스트 광고 ID (디버그 모드)
      if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/4411468910';
      } else {
        return 'ca-app-pub-3940256099942544/1033173712';
      }
    } else {
      // 실제 광고 ID (릴리즈 모드)
      if (Platform.isIOS) {
        return 'ca-app-pub-8647279125417942/6944245233';
      } else {
        // Android 광고 ID (기존)
        return 'ca-app-pub-3940256099942544/1033173712';
      }
    }
  }

  // AdMob 앱 ID (플랫폼별)
  static String get appId {
    if (kDebugMode) {
      // 테스트 앱 ID (디버그 모드)
      return 'ca-app-pub-3940256099942544~3347511713';
    } else {
      // 실제 앱 ID (릴리즈 모드)
      if (Platform.isIOS) {
        return 'ca-app-pub-8647279125417942~9562406383';
      } else {
        // Android 앱 ID (기존)
        return 'ca-app-pub-3940256099942544~3347511713';
      }
    }
  }
}
