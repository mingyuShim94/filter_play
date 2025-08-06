// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:filterplay/main.dart';
import 'package:filterplay/screens/camera_screen.dart';

void main() {
  testWidgets('App launches and shows home screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: FilterPlayApp()));
    await tester.pump();

    // Verify that our home screen is displayed.
    expect(find.text('FilterPlay'), findsOneWidget);
    expect(find.text('얼굴 인식 풍선 게임'), findsOneWidget);
  });

  testWidgets('Navigation to settings works', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: FilterPlayApp()));
    await tester.pump();

    // Tap the settings icon
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    // Verify that settings screen is displayed.
    expect(find.text('설정'), findsOneWidget);
    expect(find.text('인식 감도'), findsOneWidget);
  });

  testWidgets('Camera screen shows game title', (WidgetTester tester) async {
    // Build camera screen directly
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CameraScreen(),
        ),
      ),
    );
    await tester.pump();

    // Verify that camera screen shows game title
    expect(find.text('게임 화면'), findsOneWidget);
    // Should show initialization message
    expect(find.textContaining('카메라'), findsAtLeastNWidgets(1));
  });
}
