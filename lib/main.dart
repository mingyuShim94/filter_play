import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/ranking_filter_list_screen.dart';

void main() {
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
