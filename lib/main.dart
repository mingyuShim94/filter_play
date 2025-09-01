import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/ranking_filter_list_screen.dart';

void main() {
  // Flutter 바인딩 초기화 (AdMob 초기화 전 필수)
  WidgetsFlutterBinding.ensureInitialized();

  // 디버그/릴리즈 모드 로그 출력
  print('🚀 FilterPlay 앱 시작 - ${kDebugMode ? "디버그 모드" : "릴리즈 모드"}');

  // Google 모바일 광고 SDK 초기화
  MobileAds.instance.initialize();

  // Flutter Zone을 사용하여 print 출력 필터링
  runZoned(() {
    runApp(
      const ProviderScope(
        child: FilterPlayApp(),
      ),
    );
  }, zoneSpecification: ZoneSpecification(
    print: (Zone self, ZoneDelegate parent, Zone zone, String message) {
      // 🎬 로그만 허용

      if (message.contains('🎬')) {
        parent.print(zone, message);
      }
      // 다른 로그는 억제
    },
  ));
}

class FilterPlayApp extends StatelessWidget {
  const FilterPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FilterPlay',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const RankingFilterListScreen(),
    );
  }
}
