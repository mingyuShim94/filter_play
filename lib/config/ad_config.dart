import 'package:flutter/foundation.dart';

class AdConfig {
  // Android 전면 광고 ID
  static String get interstitialAdUnitId {
    if (kDebugMode) {
      // 테스트 광고 ID (디버그 모드)
      return 'ca-app-pub-3940256099942544/1033173712';
    } else {
      // 실제 광고 ID (릴리즈 모드)
      return 'ca-app-pub-3940256099942544/1033173712';
    }
  }

  // AdMob 앱 ID
  static String get appId {
    if (kDebugMode) {
      // 테스트 앱 ID (디버그 모드)
      return 'ca-app-pub-3940256099942544~3347511713';
    } else {
      // 실제 앱 ID (릴리즈 모드)
      return 'ca-app-pub-3940256099942544~3347511713';
    }
  }
}
